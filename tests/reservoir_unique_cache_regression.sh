#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
# Regression: two UNIQUE constraints across a 72,745-row import must remain
# bounded on the normal 64 MiB Reservoir worker.
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/asadb-reservoir-unique.XXXXXX")
DB="$WORK/reservoir-unique.asa"
SQL="$WORK/mysql_benchmark.sql"
COOKIE="$WORK/cookie.txt"
PORT=19084
PID=''

cleanup() {
  status=$?
  if [ -n "$PID" ]; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
  fi
  if [ "$status" -ne 0 ]; then
    for diagnostic in "$WORK"/*.json "$WORK"/panel.log; do
      if [ -s "$diagnostic" ]; then
        printf '\n--- %s ---\n' "$(basename "$diagnostic")" >&2
        cat "$diagnostic" >&2
      fi
    done
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT HUP INT TERM

request_sql() {
  curl -fsS -b "$COOKIE" -X POST \
    --data-urlencode "sql=$1" "http://127.0.0.1:$PORT/api/query"
}

submit_and_wait() {
  label=$1
  file=$2
  key=$3
  curl -fsS -b "$COOKIE" -X POST \
    -H 'Content-Type: application/sql;charset=UTF-8' \
    -H "X-AsaDB-Idempotency-Key: $key" \
    -H "X-AsaDB-Job-Label: $label" \
    -H 'X-AsaDB-Stop-On-Error: true' \
    --data-binary "@$file" \
    "http://127.0.0.1:$PORT/api/reservoir/jobs" > "$WORK/admission.json"
  JOB=$(sed -n 's/.*"job_id":"\([^"]*\)".*/\1/p' "$WORK/admission.json")
  test -n "$JOB"
  tries=0
  while :; do
    curl -fsS -b "$COOKIE" "http://127.0.0.1:$PORT/api/reservoir/job?id=$JOB" > "$WORK/job.json"
    if grep -q '"status":"completed"\|"status":"delivered"' "$WORK/job.json"; then
      return 0
    fi
    if grep -q '"status":"failed"\|"status":"cancelled"\|"status":"interrupted"' "$WORK/job.json"; then
      cat "$WORK/job.json" >&2
      cat "$WORK/panel.log" >&2
      return 1
    fi
    tries=$((tries + 1))
    # Projected-column correctness scans are intentionally allowed enough
    # time on slower CI disks; the worker itself remains bounded at 64 MiB.
    test "$tries" -le 7200
    sleep 0.1
  done
}

# Exact workload shape: DROP, CREATE, then 73 approximately-1,000-row INSERT
# statements.  72 * 997 + 961 = 72,745 rows.
awk 'BEGIN {
  print "DROP TABLE IF EXISTS mysql_benchmark;"
  print "CREATE TABLE mysql_benchmark (no INT PRIMARY KEY, name VARCHAR(100), student_id VARCHAR(32) UNIQUE, university VARCHAR(150), INDEX idx_university (university), INDEX idx_name (name));"
  row = 0
  for (batch = 1; batch <= 73; batch++) {
    rows = (batch == 73 ? 961 : 997)
    print "INSERT INTO mysql_benchmark (no, name, student_id, university) VALUES"
    for (i = 1; i <= rows; i++) {
      row++
      end = (i == rows ? ";" : ",")
      printf "(%d, '\''Student-%06d'\'', '\''SID-%08d'\'', '\''Institut Teknologi ITS'\'')%s\n", row, row, row, end
    }
  }
}' > "$SQL"

STATEMENTS=$(grep -c ';$' "$SQL")
test "$STATEMENTS" -eq 75
BYTES=$(wc -c < "$SQL")
test "$BYTES" -ge 4800000
test "$BYTES" -le 5300000

(cd "$ROOT" && swipl -q -s src/asadb_web.pl -- "$DB" "$PORT") \
  >"$WORK/panel.log" 2>&1 &
PID=$!

tries=0
while ! curl -fsS -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; do
  tries=$((tries + 1))
  test "$tries" -le 100
  sleep 0.1
done
curl -fsS -c "$COOKIE" "http://127.0.0.1:$PORT/" >/dev/null

request_sql 'CREATE DATABASE reservoir_unique; USE reservoir_unique;' > "$WORK/setup.json"
grep -F '"status":"error"' "$WORK/setup.json" >/dev/null && { cat "$WORK/setup.json" >&2; exit 1; } || true

submit_and_wait '72k two-unique benchmark' "$SQL" 'reservoir-unique-benchmark-v1'
request_sql 'USE reservoir_unique; SELECT COUNT(*) AS total FROM mysql_benchmark;' > "$WORK/count.json"
grep -F '72745' "$WORK/count.json" >/dev/null
grep -F '"status":"error"' "$WORK/count.json" >/dev/null && { cat "$WORK/count.json" >&2; exit 1; } || true

# Retain the exact 72,745-row reproduction above, then cross the production
# 150,000-entry budget with a small follow-up transaction.  Its two UNIQUE
# constraints force the bounded snapshot path without inflating the original
# workload or masking its expected committed count.
awk 'BEGIN {
  first = 72746
  last = 80000
  row = first
  while (row <= last) {
    batch_end = row + 996
    if (batch_end > last) batch_end = last
    print "INSERT INTO mysql_benchmark (no, name, student_id, university) VALUES"
    for (; row <= batch_end; row++) {
      end = (row == batch_end ? ";" : ",")
      printf "(%d, '\''Student-%06d'\'', '\''SID-%08d'\'', '\''Institut Teknologi ITS'\'')%s\n", row, row, row, end
    }
  }
}' > "$WORK/spill.sql"
submit_and_wait 'uniqueness snapshot rollover' "$WORK/spill.sql" 'reservoir-unique-spill-v1'
request_sql 'USE reservoir_unique; SELECT COUNT(*) AS total FROM mysql_benchmark;' > "$WORK/spill-count.json"
grep -F '80000' "$WORK/spill-count.json" >/dev/null
curl -fsS -b "$COOKIE" "http://127.0.0.1:$PORT/api/metadata" > "$WORK/metadata.json"
grep -E '"insert_validation_snapshots":[1-9][0-9]*' "$WORK/metadata.json" >/dev/null || {
  cat "$WORK/metadata.json" >&2
  exit 1
}
if find "${TMPDIR:-/tmp}" -maxdepth 1 \
    -name "swipl_asadb_insert_keys_${PID}_*" -print -quit | grep -q .; then
  printf '%s\n' 'Temporary uniqueness snapshot survived a committed import.' >&2
  exit 1
fi

# Both constraints still reject duplicates after cache snapshots/evictions.
request_sql "USE reservoir_unique; INSERT INTO mysql_benchmark VALUES (1, 'Duplicate PK', 'SID-new-pk', 'Institut Test');" > "$WORK/duplicate-pk.json"
grep -F '"status":"error"' "$WORK/duplicate-pk.json" >/dev/null
request_sql "USE reservoir_unique; INSERT INTO mysql_benchmark VALUES (80001, 'Duplicate student', 'SID-00000001', 'Institut Test');" > "$WORK/duplicate-student.json"
grep -F '"status":"error"' "$WORK/duplicate-student.json" >/dev/null

# Rollback must also release a snapshot built for an existing large table.
# The first row is valid; the second collides on the secondary UNIQUE key.
printf '%s\n' \
  "INSERT INTO mysql_benchmark VALUES (80001, 'Rollback valid', 'SID-00080001', 'Institut Test');" \
  "INSERT INTO mysql_benchmark VALUES (80002, 'Rollback duplicate', 'SID-00000001', 'Institut Test');" \
  > "$WORK/rollback-existing.sql"
if submit_and_wait 'large-table rollback verification' "$WORK/rollback-existing.sql" 'reservoir-unique-existing-rollback-v1'; then
  printf '%s\n' 'Expected existing-table duplicate import to fail.' >&2
  exit 1
fi
request_sql 'USE reservoir_unique; SELECT COUNT(*) AS total FROM mysql_benchmark;' > "$WORK/after-existing-rollback.json"
grep -F '80000' "$WORK/after-existing-rollback.json" >/dev/null
if find "${TMPDIR:-/tmp}" -maxdepth 1 \
    -name "swipl_asadb_insert_keys_${PID}_*" -print -quit | grep -q .; then
  printf '%s\n' 'Temporary uniqueness snapshot survived a rollback.' >&2
  exit 1
fi

# A failed import remains one transaction: neither the new table nor its
# first valid row may survive the following duplicate-key failure.
printf '%s\n' \
  'DROP TABLE IF EXISTS reservoir_rollback_probe;' \
  'CREATE TABLE reservoir_rollback_probe (no INT PRIMARY KEY, student_id VARCHAR(32) UNIQUE);' \
  "INSERT INTO reservoir_rollback_probe VALUES (1, 'ROLL-0001');" \
  "INSERT INTO reservoir_rollback_probe VALUES (2, 'ROLL-0001');" \
  > "$WORK/rollback.sql"
if submit_and_wait 'rollback verification' "$WORK/rollback.sql" 'reservoir-unique-rollback-v1'; then
  printf '%s\n' 'Expected duplicate-key Reservoir import to fail.' >&2
  exit 1
fi
request_sql 'USE reservoir_unique; SELECT COUNT(*) AS total FROM mysql_benchmark;' > "$WORK/after-rollback.json"
grep -F '80000' "$WORK/after-rollback.json" >/dev/null
request_sql 'USE reservoir_unique; SHOW TABLES;' > "$WORK/after-rollback-tables.json"
if grep -F 'reservoir_rollback_probe' "$WORK/after-rollback-tables.json" >/dev/null; then
  cat "$WORK/after-rollback-tables.json" >&2
  exit 1
fi

# A payload must never close Reservoir's outer transaction.  Reject embedded
# transaction control before execution so a later failure cannot preserve the
# table/row that appeared before COMMIT.
printf '%s\n' \
  'CREATE TABLE reservoir_commit_probe (id INT PRIMARY KEY);' \
  'INSERT INTO reservoir_commit_probe VALUES (1);' \
  'COMMIT;' \
  'INSERT INTO reservoir_commit_probe VALUES (1);' \
  > "$WORK/embedded-commit.sql"
if submit_and_wait 'embedded commit rejection' "$WORK/embedded-commit.sql" 'reservoir-embedded-commit-v1'; then
  printf '%s\n' 'Expected embedded COMMIT Reservoir import to fail.' >&2
  exit 1
fi
request_sql 'USE reservoir_unique; SHOW TABLES;' > "$WORK/after-embedded-commit.json"
if grep -F 'reservoir_commit_probe' "$WORK/after-embedded-commit.json" >/dev/null; then
  cat "$WORK/after-embedded-commit.json" >&2
  exit 1
fi

printf '%s\n' 'PASS: the 72,745-row MySQL workload and 80,000-row spill/rollback checks stayed bounded and correct on the 64 MiB Reservoir worker.'

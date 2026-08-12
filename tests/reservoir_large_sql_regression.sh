#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
# Real Reservoir regression for one 72,745-row / ~4.9 MiB MySQL-style INSERT.
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/asadb-reservoir-large.XXXXXX")
DB="$WORK/reservoir-large.asa"
SQL="$WORK/reservoir-large.sql"
MEDIUM_SQL="$WORK/reservoir-medium.sql"
COOKIE="$WORK/cookie.txt"
PORT=19083
PID=''

cleanup() {
  if [ -n "$PID" ]; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT HUP INT TERM

# One oversized INSERT is intentional: it exercises the streaming VALUES-row
# splitter before the SQL frontend sees the statement.  The default Reservoir
# worker remains at its normal 64 MiB stack ceiling.
awk 'BEGIN {
  print "CREATE DATABASE reservoir_large;"
  print "USE reservoir_large;"
  print "CREATE TABLE `large_rows` (`id` INT PRIMARY KEY, `note` VARCHAR(96));"
  print "INSERT INTO `large_rows` (`id`, `note`) VALUES"
  for (i = 1; i <= 72745; i++) {
    end = (i == 72745 ? ";" : ",")
    printf "(%d, '\''reservoir-row-%d-abcdefghijklmnopqrstuvwxyz-0123456789'\'')%s\n", i, i, end
  }
}' > "$SQL"

BYTES=$(wc -c < "$SQL" | tr -d ' ')
test "$BYTES" -ge 4500000

# A complete 65-512 KiB INSERT previously bypassed the 64 KiB execution
# envelope because only parser-oversized statements were split.  Keep this
# separate fixture in the exact gap range and verify it is also row-bounded.
awk 'BEGIN {
  print "CREATE TABLE `medium_rows` (`id` INT PRIMARY KEY, `note` VARCHAR(96));"
  print "INSERT INTO `medium_rows` (`id`, `note`) VALUES"
  for (i = 1; i <= 7000; i++) {
    end = (i == 7000 ? ";" : ",")
    printf "(%d, '\''medium-row-%d-abcdefghijklmnopqrstuvwxyz-0123456789'\'')%s\n", i, i, end
  }
}' > "$MEDIUM_SQL"
MEDIUM_BYTES=$(wc -c < "$MEDIUM_SQL" | tr -d ' ')
test "$MEDIUM_BYTES" -ge 300000
test "$MEDIUM_BYTES" -le 520000

(cd "$ROOT" && swipl -q -s src/asadb_web.pl -- "$DB" "$PORT") \
  >"$WORK/panel.log" 2>&1 &
PID=$!

tries=0
while ! curl -fsS -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; do
  tries=$((tries + 1))
  if [ "$tries" -gt 100 ]; then
    cat "$WORK/panel.log" >&2
    exit 1
  fi
  sleep 0.1
done
curl -fsS -c "$COOKIE" "http://127.0.0.1:$PORT/" >/dev/null

curl -fsS -b "$COOKIE" -X POST \
  -H 'Content-Type: application/octet-stream' \
  -H 'X-AsaDB-Idempotency-Key: reservoir-large-sql-v1' \
  -H 'X-AsaDB-Job-Label: 72k MySQL large SQL' \
  -H 'X-AsaDB-Stop-On-Error: true' \
  --data-binary "@$SQL" \
  "http://127.0.0.1:$PORT/api/reservoir/jobs" > "$WORK/admission.json"

JOB=$(sed -n 's/.*"job_id":"\([^"]*\)".*/\1/p' "$WORK/admission.json")
test -n "$JOB"

tries=0
while :; do
  curl -fsS -b "$COOKIE" \
    "http://127.0.0.1:$PORT/api/reservoir/job?id=$JOB" > "$WORK/job.json"
  if grep -q '"status":"completed"\|"status":"delivered"' "$WORK/job.json"; then
    break
  fi
  if grep -q '"status":"failed"\|"status":"cancelled"\|"status":"interrupted"' "$WORK/job.json"; then
    cat "$WORK/job.json" >&2
    cat "$WORK/panel.log" >&2
    exit 1
  fi
  tries=$((tries + 1))
  test "$tries" -le 1200
  sleep 0.1
done

curl -fsS -b "$COOKIE" -X POST \
  --data-urlencode 'sql=USE reservoir_large; SELECT COUNT(*) AS total FROM large_rows;' \
  "http://127.0.0.1:$PORT/api/query" > "$WORK/count.json"
grep -F '72745' "$WORK/count.json" >/dev/null
grep -F '"status":"error"' "$WORK/count.json" >/dev/null && exit 1 || true

curl -fsS -b "$COOKIE" -X POST \
  -H 'Content-Type: application/octet-stream' \
  -H 'X-AsaDB-Idempotency-Key: reservoir-medium-sql-v1' \
  -H 'X-AsaDB-Job-Label: bounded complete INSERT' \
  -H 'X-AsaDB-Logical-Database: reservoir_large' \
  -H 'X-AsaDB-Stop-On-Error: true' \
  --data-binary "@$MEDIUM_SQL" \
  "http://127.0.0.1:$PORT/api/reservoir/jobs" > "$WORK/admission-medium.json"
JOB=$(sed -n 's/.*"job_id":"\([^"]*\)".*/\1/p' "$WORK/admission-medium.json")
test -n "$JOB"
tries=0
while :; do
  curl -fsS -b "$COOKIE" \
    "http://127.0.0.1:$PORT/api/reservoir/job?id=$JOB" > "$WORK/job-medium.json"
  if grep -q '"status":"completed"\|"status":"delivered"' "$WORK/job-medium.json"; then
    break
  fi
  if grep -q '"status":"failed"\|"status":"cancelled"\|"status":"interrupted"' "$WORK/job-medium.json"; then
    cat "$WORK/job-medium.json" >&2
    cat "$WORK/panel.log" >&2
    exit 1
  fi
  tries=$((tries + 1))
  test "$tries" -le 1200
  sleep 0.1
done
curl -fsS -b "$COOKIE" -X POST \
  --data-urlencode 'sql=USE reservoir_large; SELECT COUNT(*) AS total FROM medium_rows;' \
  "http://127.0.0.1:$PORT/api/query" > "$WORK/medium-count.json"
grep -F '7000' "$WORK/medium-count.json" >/dev/null
grep -F '"status":"error"' "$WORK/medium-count.json" >/dev/null && exit 1 || true

printf 'PASS: normal 64 MiB Reservoir worker imported %s-byte oversized and %s-byte complete INSERTs with bounded execution batches.\n' "$BYTES" "$MEDIUM_BYTES"

#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
# End-to-end backend interchange and Reservoir import contract.
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/asadb-interchange-http.XXXXXX")
DB="$WORK/interchange.asa"
COOKIE="$WORK/cookie.txt"
PID=''
PORT=19082

cleanup() {
  if [ -n "$PID" ]; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT HUP INT TERM

(cd "$ROOT" && swipl -q -s src/asadb_web.pl -- "$DB" "$PORT") \
  >"$WORK/panel.log" 2>&1 &
PID=$!

tries=0
while ! curl -fsS -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; do
  tries=$((tries + 1))
  if [ "$tries" -gt 80 ]; then
    cat "$WORK/panel.log" >&2
    exit 1
  fi
  sleep 0.1
done
curl -fsS -c "$COOKIE" "http://127.0.0.1:$PORT/" >/dev/null

post_sql() {
  curl -fsS -b "$COOKIE" -X POST --data-urlencode "sql=$1" \
    "http://127.0.0.1:$PORT/api/query" >"$WORK/query.json"
  if grep -q '"status":"error"' "$WORK/query.json"; then
    cat "$WORK/query.json" >&2
    exit 1
  fi
}

post_sql "CREATE DATABASE interchange_http; USE interchange_http; CREATE TABLE people (id INT PRIMARY KEY, name TEXT, score DOUBLE); INSERT INTO people VALUES (1, 'Ayu', 98.5), (2, '日本', 87), (3, 'O\\'Brien', -4.25);"

curl -fsS -b "$COOKIE" -X POST \
  -d 'database=interchange_http&format=mysql&output=save&tables=people&data_tables=people&include_schema=true&include_data=true&create_database=false&drop_tables=true' \
  "http://127.0.0.1:$PORT/api/export" -o "$WORK/people.mysql"
grep -F 'INSERT INTO `people`' "$WORK/people.mysql" >/dev/null
grep -F 'Ayu' "$WORK/people.mysql" >/dev/null

curl -fsS -b "$COOKIE" -X POST \
  -d 'database=interchange_http&format=postgresql&output=save&tables=people&data_tables=people&include_schema=true&include_data=true&create_database=false&drop_tables=true' \
  "http://127.0.0.1:$PORT/api/export" -o "$WORK/people.pgsql"
grep -F 'COPY "people"' "$WORK/people.pgsql" >/dev/null
grep -F 'Ayu' "$WORK/people.pgsql" >/dev/null

curl -fsS -b "$COOKIE" -X POST \
  -d 'database=interchange_http&format=csv&output=save&tables=people&data_tables=people&include_schema=true&include_data=true' \
  "http://127.0.0.1:$PORT/api/export" -o "$WORK/people.csv"
grep -F 'id,name,score' "$WORK/people.csv" >/dev/null
grep -F 'Ayu' "$WORK/people.csv" >/dev/null

curl -fsS -b "$COOKIE" -X POST \
  -d 'database=interchange_http&format=xlsx&output=save&tables=people&data_tables=people&include_schema=true&include_data=true' \
  "http://127.0.0.1:$PORT/api/export" -o "$WORK/people.xlsx"
unzip -t "$WORK/people.xlsx" >/dev/null
unzip -p "$WORK/people.xlsx" xl/worksheets/sheet1.xml | grep -F 'Ayu' >/dev/null

submit_import() {
  FILE=$1
  FORMAT=$2
  NAME=$3
  TABLE=$4
  curl -fsS -b "$COOKIE" -X POST \
    -H 'Content-Type: application/octet-stream' \
    -H "X-AsaDB-Idempotency-Key: $FORMAT-$TABLE" \
    -H "X-AsaDB-Job-Label: $NAME" \
    -H "X-AsaDB-Import-Format: $FORMAT" \
    -H "X-AsaDB-Import-Name: $NAME" \
    -H "X-AsaDB-Import-Table: $TABLE" \
    -H 'X-AsaDB-Import-Mode: replace' \
    --data-binary "@$FILE" \
    "http://127.0.0.1:$PORT/api/reservoir/jobs" >"$WORK/admission.json"
  JOB=$(sed -n 's/.*"job_id":"\([^"]*\)".*/\1/p' "$WORK/admission.json")
  test -n "$JOB"
  tries=0
  while :; do
    curl -fsS -b "$COOKIE" \
      "http://127.0.0.1:$PORT/api/reservoir/job?id=$JOB" \
      >"$WORK/job.json"
    if grep -q '"status":"completed"\|"status":"delivered"' "$WORK/job.json"; then
      break
    fi
    if grep -q '"status":"failed"\|"status":"cancelled"' "$WORK/job.json"; then
      cat "$WORK/job.json" >&2
      cat "$WORK/panel.log" >&2
      exit 1
    fi
    tries=$((tries + 1))
    test "$tries" -le 100
    sleep 0.05
  done
  curl -fsS -b "$COOKIE" \
    "http://127.0.0.1:$PORT/api/reservoir/result?id=$JOB&offset=0&limit=250" \
    >"$WORK/result.json"
  grep -F '"status":"table"' "$WORK/result.json" >/dev/null
}

submit_import "$WORK/people.csv" csv people.csv people_csv
post_sql 'SELECT COUNT(*) AS total FROM people_csv; SELECT name FROM people_csv WHERE id = 1;'
grep -F '3' "$WORK/query.json" >/dev/null
grep -F 'Ayu' "$WORK/query.json" >/dev/null

submit_import "$WORK/people.xlsx" xlsx people.xlsx people_xlsx
post_sql 'SELECT COUNT(*) AS total FROM people_xlsx; SELECT name FROM people_xlsx WHERE id = 1;'
grep -F '3' "$WORK/query.json" >/dev/null
grep -F 'Ayu' "$WORK/query.json" >/dev/null

echo 'PASS: HTTP backend export and Reservoir CSV/XLSX import passed.'

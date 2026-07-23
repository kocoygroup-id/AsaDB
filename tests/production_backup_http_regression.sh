#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
# End-to-end production backup contract: authenticated backend snapshot,
# native artifact verification, and backend restore into a clean engine.
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/asadb-production-backup.XXXXXX")
SOURCE_DB="$WORK/source.asa"
DESTINATION_DB="$WORK/destination.asa"
BACKUP="$WORK/production.asb"
CORRUPT="$WORK/corrupt.asb"
BAD_MAGIC="$WORK/bad-magic.asb"
COOKIE="$WORK/cookie.txt"
PID=''
PORT=19081

cleanup() {
  if [ -n "$PID" ]; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT HUP INT TERM

wait_for_panel() {
  tries=0
  while ! curl -fsS -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 80 ]; then
      echo 'production backup HTTP regression: panel did not start' >&2
      exit 1
    fi
    sleep 0.1
  done
}

start_panel() {
  DB=$1
  (cd "$ROOT" && swipl -q -s src/asadb_web.pl -- "$DB" "$PORT") >"$WORK/panel.log" 2>&1 &
  PID=$!
  wait_for_panel
  curl -fsS -c "$COOKIE" "http://127.0.0.1:$PORT/" >/dev/null
}

stop_panel() {
  kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
  PID=''
}

post_sql() {
  curl -fsS -b "$COOKIE" -X POST --data-urlencode "sql=$1" \
    "http://127.0.0.1:$PORT/api/query" >"$WORK/query.json"
  if grep -q '"status":"error"' "$WORK/query.json"; then
    cat "$WORK/query.json" >&2
    exit 1
  fi
}

insert_batch() {
  FIRST=$1
  LAST=$2
  SQL='INSERT INTO backup_rows (id, note) VALUES '
  I=$FIRST
  while [ "$I" -le "$LAST" ]; do
    if [ "$I" -gt "$FIRST" ]; then SQL="$SQL, "; fi
    SQL="$SQL($I, 'row-$I')"
    I=$((I + 1))
  done
  post_sql "$SQL;"
}

start_panel "$SOURCE_DB"

UNAUTH=$(curl -sS -o "$WORK/unauth.json" -w '%{http_code}' -X POST -d 'database=none' "http://127.0.0.1:$PORT/api/backup")
test "$UNAUTH" = '403'

# Smoke the authenticated endpoints consumed by both UI bundles before the
# backup flow starts.  The backup regression is therefore also a direct
# frontend-contract check for state, catalog/metadata, and Reservoir status.
curl -fsS -b "$COOKIE" "http://127.0.0.1:$PORT/api/state" >"$WORK/state.json"
grep -F '"status":"table"' "$WORK/state.json" >/dev/null
curl -fsS -b "$COOKIE" "http://127.0.0.1:$PORT/api/metadata" >"$WORK/metadata.json"
grep -F '"engine_version"' "$WORK/metadata.json" >/dev/null
curl -fsS -b "$COOKIE" "http://127.0.0.1:$PORT/api/reservoir/stats" >"$WORK/reservoir.json"
grep -F '"enabled":true' "$WORK/reservoir.json" >/dev/null

post_sql 'CREATE DATABASE production_http; USE production_http; CREATE TABLE backup_rows (id INT PRIMARY KEY, note TEXT); BEGIN;'
FIRST=1
while [ "$FIRST" -le 6137 ]; do
  LAST=$((FIRST + 255))
  if [ "$LAST" -gt 6137 ]; then LAST=6137; fi
  insert_batch "$FIRST" "$LAST"
  FIRST=$((LAST + 1))
done
post_sql 'COMMIT; CREATE INDEX backup_note_idx ON backup_rows (note); CREATE VIEW backup_view AS SELECT id, note FROM backup_rows;'

curl -fsS -b "$COOKIE" "http://127.0.0.1:$PORT/api/catalog" >"$WORK/catalog.json"
grep -F '"row_count"' "$WORK/catalog.json" >/dev/null
grep -F '6137' "$WORK/catalog.json" >/dev/null

# No browser rows or sandbox data are sent: the server gets just the database
# identifier and emits an attachment built from the record-store heap.
curl -fsS -b "$COOKIE" -X POST -d 'database=production_http&output=save' \
  "http://127.0.0.1:$PORT/api/backup" -o "$BACKUP"
grep -F -- '-- ASADB-PRODUCTION-BACKUP 1' "$BACKUP" >/dev/null
grep -F -- '-- payload-sha256: ' "$BACKUP" >/dev/null
grep -F -- '-- integrity-sha256: ' "$BACKUP" >/dev/null
grep -F -- '-- row-count: 6137' "$BACKUP" >/dev/null

cp "$BACKUP" "$CORRUPT"
sed -i '0,/row-1/s/row-1/row-X/' "$CORRUPT"
cp "$BACKUP" "$BAD_MAGIC"
printf 'X' | dd of="$BAD_MAGIC" bs=1 count=1 conv=notrunc status=none

stop_panel
start_panel "$DESTINATION_DB"

CORRUPT_STATUS=$(curl -sS -o "$WORK/corrupt.json" -w '%{http_code}' -b "$COOKIE" -X POST \
  -F "file=@$CORRUPT;filename=corrupt.asb" -F 'stop_on_error=true' \
  "http://127.0.0.1:$PORT/api/import_upload")
test "$CORRUPT_STATUS" = '400'

BAD_MAGIC_STATUS=$(curl -sS -o "$WORK/bad-magic.json" -w '%{http_code}' -b "$COOKIE" -X POST \
  -F "file=@$BAD_MAGIC;filename=bad-magic.asb" -F 'stop_on_error=true' \
  "http://127.0.0.1:$PORT/api/import_upload")
test "$BAD_MAGIC_STATUS" = '400'

post_sql 'BEGIN;'
ACTIVE_TRANSACTION_STATUS=$(curl -sS -o "$WORK/active-transaction.json" -w '%{http_code}' -b "$COOKIE" -X POST \
  -F "file=@$BACKUP;filename=production.asb" -F 'stop_on_error=true' \
  "http://127.0.0.1:$PORT/api/import_upload")
test "$ACTIVE_TRANSACTION_STATUS" = '400'
post_sql 'ROLLBACK;'

RESTORE_STATUS=$(curl -sS -o "$WORK/restore.json" -w '%{http_code}' -b "$COOKIE" -X POST \
  -F "file=@$BACKUP;filename=production.asb" -F 'stop_on_error=true' \
  "http://127.0.0.1:$PORT/api/import_upload")
if [ "$RESTORE_STATUS" != '200' ]; then
  cat "$WORK/restore.json" >&2
  cat "$WORK/panel.log" >&2
  exit 1
fi
grep -F '"status":"table"' "$WORK/restore.json" >/dev/null

curl -fsS -b "$COOKIE" "http://127.0.0.1:$PORT/api/catalog" >"$WORK/restored-catalog.json"
grep -F '"row_count"' "$WORK/restored-catalog.json" >/dev/null
grep -F '6137' "$WORK/restored-catalog.json" >/dev/null
grep -F 'backup_view' "$WORK/restored-catalog.json" >/dev/null
post_sql 'USE production_http; SELECT id, note FROM backup_rows WHERE id = 1; SELECT id, note FROM backup_rows WHERE id = 3072; SELECT id, note FROM backup_rows WHERE id = 6137;'
grep -F 'row-1' "$WORK/query.json" >/dev/null
grep -F 'row-3072' "$WORK/query.json" >/dev/null
grep -F 'row-6137' "$WORK/query.json" >/dev/null

echo 'PASS: authenticated backend production backup and verified restore passed.'

#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/asadb-launcher.XXXXXX")
FAKE_BIN="$TMP_DIR/bin"
mkdir -p "$FAKE_BIN"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT HUP INT TERM

printf '%s\n' \
  '#!/bin/sh' \
  'for argument do' \
  '  printf "%s\\n" "$argument"' \
  'done' > "$FAKE_BIN/swipl"
chmod 755 "$FAKE_BIN/swipl"

assert_output() {
  Label=$1
  Expected=$2
  Actual=$3
  if [ "$Actual" != "$Expected" ]; then
    printf 'FAIL: %s argument forwarding changed.\nExpected:\n%s\nActual:\n%s\n' \
      "$Label" "$Expected" "$Actual" >&2
    exit 1
  fi
}

BIN_OUTPUT=$(PATH="$FAKE_BIN:$PATH" "$ROOT/bin/asadb" "database with spaces.asa" "query with spaces.sql")
BIN_EXPECTED=$(printf '%s\n' -q -s "$ROOT/src/asadb.pl" -- "database with spaces.asa" "query with spaces.sql")
assert_output bin/asadb "$BIN_EXPECTED" "$BIN_OUTPUT"

CLI_OUTPUT=$(PATH="$FAKE_BIN:$PATH" "$ROOT/scripts/run_asadb.sh" "database with spaces.asa" "query with spaces.sql")
CLI_EXPECTED=$(printf '%s\n' -q -s src/asadb.pl -- "database with spaces.asa" "query with spaces.sql")
assert_output run_asadb.sh "$CLI_EXPECTED" "$CLI_OUTPUT"

PANEL_OUTPUT=$(PATH="$FAKE_BIN:$PATH" "$ROOT/scripts/run_panel.sh" "database with spaces.asa" 8099)
PANEL_EXPECTED=$(printf '%s\n' -q -s src/asadb_web.pl -- "database with spaces.asa" 8099)
assert_output run_panel.sh "$PANEL_EXPECTED" "$PANEL_OUTPUT"

printf 'PASS: Linux launchers preserve arguments and paths containing spaces.\n'

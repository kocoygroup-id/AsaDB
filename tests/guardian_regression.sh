#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/asadb-guardian.XXXXXX")

cleanup() {
  rm -rf "$WORK"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$WORK/src/nested" "$WORK/scripts"
printf '%s\n' 'guardian=true' > "$WORK/asadb.conf"
printf '%s\n' 'all:' '\ttrue' > "$WORK/Makefile"
printf '%s\n' ':- module(guardian_fixture, []).' > "$WORK/src/nested/fixture.pl"
printf '%s\n' '#!/bin/sh' 'printf guardian-child' > "$WORK/scripts/fixture.sh"
printf '%s\n' 'not selected' > "$WORK/ignored.txt"

"$ROOT/scripts/asadb_guardian.sh" --once --root "$WORK" --exclude 'scripts/*'

test -f "$WORK/.asa-guardian/current/asadb.conf"
test -f "$WORK/.asa-guardian/current/Makefile"
test -f "$WORK/.asa-guardian/current/src/nested/fixture.pl"
test ! -e "$WORK/.asa-guardian/current/scripts/fixture.sh"
test ! -e "$WORK/.asa-guardian/current/ignored.txt"

swipl -q -g "use_module(library(http/json)),setup_call_cleanup(open('$WORK/.asa-guardian/manifest.json',read,In,[encoding(utf8)]),json_read_dict(In,Manifest),close(In)),get_dict(files,Manifest,Files),length(Files,3),member(Entry,Files),get_dict(path,Entry,\"src/nested/fixture.pl\"),get_dict(sha256,Entry,_),halt" -t halt

"$ROOT/scripts/asadb_guardian.sh" --once --root "$WORK" --exclude 'scripts/*'
tail -n 1 "$WORK/.asa-guardian/guardian.log" | grep -F 'copied:0' >/dev/null
tail -n 1 "$WORK/.asa-guardian/guardian.log" | grep -F 'kept:3' >/dev/null

"$ROOT/scripts/asadb_guardian.sh" --root "$WORK" -- sh -c 'printf guardian-child'
grep -F 'child_output' "$WORK/.asa-guardian/guardian.log" >/dev/null
grep -F 'child_exit' "$WORK/.asa-guardian/guardian.log" >/dev/null

echo 'PASS: Asa Process Guardian snapshot and supervisor checks passed.'

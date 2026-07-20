#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
VERSION=$(sed -n '1p' "$ROOT/VERSION")
NAME="AsaDB-$VERSION-windows-source"
ARCHIVE="$ROOT/dist/$NAME.zip"
CHECKSUM="$ARCHIVE.sha256"
LIST=$(mktemp "${TMPDIR:-/tmp}/asadb-windows-source-list.XXXXXX")

cleanup() {
  rm -f "$LIST"
}
trap cleanup EXIT HUP INT TERM

"$ROOT/scripts/build_windows_source_release.sh"
test -s "$ARCHIVE"
test -s "$CHECKSUM"
(cd "$ROOT/dist" && sha256sum -c "$(basename "$CHECKSUM")")
unzip -Z1 "$ARCHIVE" > "$LIST"

for required in \
  LICENSE README.md INSTALL.md SOURCE_CODE.md VERSION \
  scripts/run_asadb.bat scripts/run_panel.bat scripts/asadb_guardian.sh \
  src/asadb.pl src/asadb_web.pl src/bridge/reservoir.pl \
  web/index.html web/assets/app.js
do
  if ! grep -Fx "$NAME/$required" "$LIST" >/dev/null; then
    echo "Windows source ZIP is missing required path: $required" >&2
    exit 1
  fi
done

if grep -E '/(build|dist)/|/asadb\.port$|\.asa($|\.)|\.wal$|\.log$|\.exe$' "$LIST" >/dev/null; then
  echo 'Windows source ZIP contains runtime or executable residue.' >&2
  exit 1
fi

printf 'PASS: %s is clean, checksummed, and contains the Windows source launchers.\n' "$(basename "$ARCHIVE")"

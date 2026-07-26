#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
VERSION=$(sed -n '1p' "$ROOT/VERSION")
SOURCE_NAME="AsaDB-$VERSION"
WINDOWS_NAME="AsaDB-$VERSION-windows-source"
DIST="$ROOT/dist"
SOURCE_ARCHIVE="$DIST/$SOURCE_NAME.tar.Z"
ARCHIVE="$DIST/$WINDOWS_NAME.zip"
CHECKSUM="$ARCHIVE.sha256"
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/asadb-windows-source.XXXXXX")

cleanup() {
  rm -rf "$STAGE"
}
trap cleanup EXIT HUP INT TERM

# Always stage the current source tree. Reusing an older source archive can
# silently omit a newly added runtime module from the Windows ZIP.
ASADB_RELEASE_PLATFORM=source "$ROOT/scripts/build_source_release.sh"

tar -xzf "$SOURCE_ARCHIVE" -C "$STAGE"
mv "$STAGE/$SOURCE_NAME" "$STAGE/$WINDOWS_NAME"

(
  cd "$STAGE"
  zip -qr "$ARCHIVE" "$WINDOWS_NAME"
)

(
  cd "$DIST"
  sha256sum "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM")"
)

printf 'Created %s\n' "$ARCHIVE"
printf 'Created %s\n' "$CHECKSUM"
printf '%s\n' 'This is a Windows source-launcher package; install SWI-Prolog before running the .bat launchers.'

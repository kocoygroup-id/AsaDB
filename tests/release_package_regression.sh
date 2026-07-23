#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
VERSION=$(sed -n '1p' "$ROOT/VERSION")
NAME="AsaDB-$VERSION-linux-x86_64"
ARCHIVE="$ROOT/dist/$NAME.tar.Z"
CHECKSUM="$ARCHIVE.sha256"
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/asadb-release.XXXXXX")
LIST_FILE="$TMP_DIR/archive.list"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT HUP INT TERM

"$ROOT/scripts/build_linux_release.sh"
test -s "$ARCHIVE"
test -s "$CHECKSUM"

(cd "$ROOT/dist" && sha256sum -c "$(basename "$CHECKSUM")")
gzip -t "$ARCHIVE"
tar -tzf "$ARCHIVE" > "$LIST_FILE"

if grep -Ev "^$NAME(/|$)" "$LIST_FILE" >/dev/null; then
  echo "Release contains a path outside $NAME/." >&2
  exit 1
fi

for required in \
  LICENSE README.md RELEASE.md RELEASE_NOTES.md COMPATIBILITY.md INSTALL.md VERSION \
  THIRD_PARTY_NOTICES.md licenses/Noto-Sans-JP-OFL-1.1.txt \
  bin/asadb scripts/run_asadb.sh scripts/run_panel.sh scripts/asadb_guardian.sh scripts/check_linux_runtime.sh scripts/build_legacy_frontend.sh scripts/build_windows_source_release.sh \
  scripts/build_windows_exe.ps1 scripts/check_realtime_release.sh scripts/check_realtime_release.ps1 \
  scripts/realtime_release_contract.txt \
  src/asadb_core.pl src/asadb_backup.pl src/asadb_pager.pl src/bridge/karyawan.pl src/bridge/reservoir.pl src/bridge/horsemen/contract/war/here/yoru_the_wardevil.pl web/index.html web/assets/app.js \
  web/assets/app.legacy.js web/assets/app-loader.js \
  web/assets/fonts/noto-sans-jp-japanese-400-normal.woff2 web/assets/fonts/noto-sans-jp-japanese-400-normal.woff \
  tests/run_tests.pl tests/join_15000_regression.pl tests/production_backup_regression.pl tests/production_backup_http_regression.sh tests/guardian_regression.sh tests/windows_source_package_regression.sh tests/ui_regression.js \
  tests/launcher_regression.sh tests/release_package_regression.sh
do
  if ! grep -Fx "$NAME/$required" "$LIST_FILE" >/dev/null; then
    echo "Release is missing required path: $required" >&2
    exit 1
  fi
done

if grep -E '/(build|dist)/|/asadb\.port$|\.exe$|\.asa($|\.)|\.asa\.(store|reservoir)/|\.wal$|\.log$|/benchmark-results-' "$LIST_FILE" >/dev/null; then
  echo "Release contains forbidden runtime, benchmark, or binary residue." >&2
  exit 1
fi

tar -xzf "$ARCHIVE" -C "$TMP_DIR"
test -x "$TMP_DIR/$NAME/bin/asadb"
test -x "$TMP_DIR/$NAME/scripts/run_asadb.sh"
test -x "$TMP_DIR/$NAME/scripts/run_panel.sh"
test -x "$TMP_DIR/$NAME/scripts/check_linux_runtime.sh"
test -x "$TMP_DIR/$NAME/scripts/asadb_guardian.sh"
test -x "$TMP_DIR/$NAME/scripts/check_realtime_release.sh"
grep -F "GNU GENERAL PUBLIC LICENSE" "$TMP_DIR/$NAME/LICENSE" >/dev/null

# Realtime panel fixes must be shipped from the same checked-in source tree.
# Byte-for-byte checks catch a stale archive assembled from an older frontend or
# Reservoir backend even when the expected filenames still exist.
for mirrored in \
  src/asadb_web.pl src/bridge/reservoir.pl \
  web/index.html web/assets/app.js web/assets/app.legacy.js web/assets/style.css
do
  if ! cmp -s "$ROOT/$mirrored" "$TMP_DIR/$NAME/$mirrored"; then
    echo "Release does not contain the current source bytes: $mirrored" >&2
    exit 1
  fi
done

# The Windows executable embeds the same Prolog backend and copies the same web
# directory. This static contract is intentionally checked on Linux CI, where
# PowerShell and the Windows SWI-Prolog runtime are not necessarily available.
WINDOWS_BUILD="$ROOT/scripts/build_windows_exe.ps1"
LINUX_BUILD="$ROOT/scripts/build_source_release.sh"
PORTABLE_ENTRY="$ROOT/src/asa_portable.pl"
if ! grep -F "['src/asa_portable.pl']" "$WINDOWS_BUILD" >/dev/null ||
   ! grep -F 'qsave_program' "$WINDOWS_BUILD" >/dev/null ||
   ! grep -F 'ensure_loaded('\''asadb_web.pl'\'')' "$PORTABLE_ENTRY" >/dev/null; then
  echo "Windows build no longer embeds the canonical AsaDB web backend." >&2
  exit 1
fi
if ! grep -F 'Copy-Item -Path (Join-Path $Root "web") -Destination (Join-Path $Dist "web") -Recurse -Force' "$WINDOWS_BUILD" >/dev/null; then
  echo "Windows build no longer packages the canonical AsAPanel web tree." >&2
  exit 1
fi
if ! grep -F 'scripts\check_realtime_release.ps1' "$WINDOWS_BUILD" >/dev/null ||
   ! grep -F 'scripts/check_realtime_release.sh' "$LINUX_BUILD" >/dev/null; then
  echo "A platform build no longer enforces the shared realtime release contract." >&2
  exit 1
fi

printf 'PASS: %s is clean, checksummed, GPL-complete, executable, and shares the Windows realtime sources.\n' "$(basename "$ARCHIVE")"

#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
VERSION=$(sed -n '1p' "$ROOT/VERSION")
PLATFORM=${ASADB_RELEASE_PLATFORM:-source}

"$ROOT/scripts/check_realtime_release.sh"

case "$PLATFORM" in
  source)
    NAME="AsaDB-$VERSION"
    ;;
  linux-x86_64)
    NAME="AsaDB-$VERSION-linux-x86_64"
    ;;
  *)
    echo "Unsupported release platform: $PLATFORM" >&2
    exit 2
    ;;
esac

DIST="$ROOT/dist"
STAGE="$DIST/.stage-$NAME"
TAR_FILE="$DIST/$NAME.tar"
OUTPUT="$DIST/$NAME.tar.Z"
CHECKSUM_FILE="$OUTPUT.sha256"

case "$STAGE" in
  "$ROOT"/dist/.stage-AsaDB-*) ;;
  *) echo "Refusing unsafe stage path: $STAGE" >&2; exit 1 ;;
esac

rm -rf "$STAGE"
mkdir -p "$STAGE/$NAME" "$DIST"

for path in \
  BENCHMARK_RESULTS.md BUGFIX_REPORT.txt CODE_OF_CONDUCT.md CONTRIBUTING.md DCO GOVERNANCE.md \
  COMPATIBILITY.md INSTALL.md LICENSE LICENSE_HISTORY.md Makefile OPEN_SOURCE_RELEASE_CHECKLIST.md \
  README.md RELEASE.md RELEASE_NOTES.md SECURITY.md SOURCE_CODE.md THIRD_PARTY_NOTICES.md \
  TRADEMARKS.md VERSION asadb.conf bin examples docs licenses scripts src tests tools web \
  .github .gitattributes .gitignore
do
  if [ -e "$ROOT/$path" ]; then
    parent=$(dirname "$path")
    mkdir -p "$STAGE/$NAME/$parent"
    cp -R "$ROOT/$path" "$STAGE/$NAME/$path"
  fi
done

if [ -d "$ROOT/stress tests" ]; then
  cp -R "$ROOT/stress tests" "$STAGE/$NAME/stress tests"
fi

# Runtime databases, logs, generated SQL, and binary output are not source.
rm -rf "$STAGE/$NAME/tests/"*.asa.store \
       "$STAGE/$NAME/tests/"*.asa.reservoir \
       "$STAGE/$NAME/tests/benchmark-results-"*
rm -f "$STAGE/$NAME/tests/"*.asa \
      "$STAGE/$NAME/tests/"*.asa.* \
      "$STAGE/$NAME/tests/"*.log \
      "$STAGE/$NAME/tests/"*_generated.sql

tar -cf "$TAR_FILE" -C "$STAGE" "$NAME"
gzip -n -9 -c "$TAR_FILE" > "$OUTPUT"
rm -f "$TAR_FILE"
rm -rf "$STAGE"

OUTPUT_NAME=$(basename "$OUTPUT")
CHECKSUM_NAME=$(basename "$CHECKSUM_FILE")
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$DIST" && sha256sum "$OUTPUT_NAME" > "$CHECKSUM_NAME")
elif command -v shasum >/dev/null 2>&1; then
  (cd "$DIST" && shasum -a 256 "$OUTPUT_NAME" > "$CHECKSUM_NAME")
else
  echo "Neither sha256sum nor shasum is available; release checksum was not created." >&2
  exit 1
fi

printf 'Created %s\n' "$OUTPUT"
printf 'Created %s\n' "$CHECKSUM_FILE"
printf 'Extract with: tar -xzf %s\n' "$(basename "$OUTPUT")"

#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
# Rebuild the Firefox-38-compatible runtime bundle from web/assets/app.js.
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
SOURCE="$ROOT/web/assets/app.js"
OUTPUT="$ROOT/web/assets/app.legacy.js"
TEMP_DIR=''

cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT HUP INT TERM

MODULES=${ASADB_BABEL_NODE_MODULES:-}
if [ -z "$MODULES" ]; then
  if ! command -v npm >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1; then
    echo "Cannot rebuild app.legacy.js: install Node.js with npm, or set ASADB_BABEL_NODE_MODULES." >&2
    exit 2
  fi

  TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/asadb-babel.XXXXXX")
  NPM_CACHE=${NPM_CONFIG_CACHE:-}
  if [ -z "$NPM_CACHE" ] || [ ! -d "$NPM_CACHE" ] || [ ! -w "$NPM_CACHE" ]; then
    NPM_CONFIG_CACHE="${TMPDIR:-/tmp}/asadb-npm-cache"
    export NPM_CONFIG_CACHE
    mkdir -p "$NPM_CONFIG_CACHE"
  fi
  echo "Using npm to obtain the pinned Babel compiler..." >&2
  npm install --prefix "$TEMP_DIR" --no-save --no-package-lock --ignore-scripts \
    @babel/core@7.26.0 @babel/preset-env@7.26.0 >/dev/null
  MODULES="$TEMP_DIR/node_modules"
fi

node "$ROOT/tools/build_legacy_frontend.js" "$MODULES" "$SOURCE" "$OUTPUT"
echo "Built $OUTPUT"

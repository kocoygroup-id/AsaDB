#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -eu
DB_FILE="${1:-data.asa}"
PORT="${2:-8088}"
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

if ! command -v swipl >/dev/null 2>&1; then
  echo "AsaDB: SWI-Prolog (swipl) tidak ditemukan di PATH." >&2
  echo "Lihat INSTALL.md, termasuk petunjuk khusus 4MLinux." >&2
  exit 127
fi

case "$DB_FILE" in
  /*) DB_PATH=$DB_FILE ;;
  *) DB_PATH=$ROOT/$DB_FILE ;;
esac
DB_DIR=$(dirname "$DB_PATH")
mkdir -p "$DB_DIR"
DB_DIR=$(CDPATH= cd "$DB_DIR" && pwd)
DB_NAME=$(basename "$DB_PATH")

cd "$ROOT"
exec swipl -q -s tools/asadb_launcher.pl -- start \
  --database "$DB_NAME" \
  --data-dir "$DB_DIR" \
  --port "$PORT"

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

cd "$ROOT"
exec swipl -q -s src/asadb_web.pl -- "$DB_FILE" "$PORT"

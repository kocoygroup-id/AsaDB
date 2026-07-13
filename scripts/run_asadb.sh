#!/usr/bin/env bash
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
DB_FILE="${1:-data.asa}"
SQL_FILE="${2:-}"
cd "$(dirname "$0")/.."
if [[ -n "$SQL_FILE" ]]; then
  swipl -q -s src/asadb.pl -- "$DB_FILE" "$SQL_FILE"
else
  swipl -q -s src/asadb.pl -- "$DB_FILE"
fi

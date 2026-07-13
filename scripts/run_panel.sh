#!/usr/bin/env bash
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
DB_FILE="${1:-data.asa}"
PORT="${2:-8088}"
cd "$(dirname "$0")/.."
swipl -q -s src/asadb_web.pl -- "$DB_FILE" "$PORT"

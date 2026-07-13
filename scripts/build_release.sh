#!/usr/bin/env bash
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swipl -q -s src/asadb_release.pl

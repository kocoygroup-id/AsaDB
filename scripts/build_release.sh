#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -eu
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
mkdir -p build
exec swipl -q -s src/asadb_release.pl

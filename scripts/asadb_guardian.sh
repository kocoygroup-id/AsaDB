#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
exec swipl -q -s "$ROOT/src/bridge/horsemen/contract/war/here/yoru_the_wardevil.pl" -- "$@"

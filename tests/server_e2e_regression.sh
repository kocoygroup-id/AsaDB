#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
TEMP_ROOT=$(mktemp -d /tmp/asadb-server-e2e.XXXXXX)
cleanup() {
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

export ASADB_HOME="$TEMP_ROOT/home"
export ASADB_REPO_ROOT="$ROOT"
python3 "$ROOT/flaskserver/scripts/bootstrap_python.py" setup
PYTHON="$ASADB_HOME/python-env/bin/python"
"$PYTHON" "$ROOT/flaskserver/tests/hardening_regression.py"
"$PYTHON" "$ROOT/flaskserver/tests/e2e_prolog_server.py"
python3 "$ROOT/flaskserver/scripts/bootstrap_python.py" doctor --json
printf '%s\n' 'PASS: offline wheelhouse and real Flask-to-SWI-Prolog server E2E regression.'

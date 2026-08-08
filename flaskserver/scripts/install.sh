#!/bin/sh
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e ".[dev]"

echo
echo "Installed. Set ASADB_REPO_ROOT to the AsaDB repository root, then run:"
echo "  . .venv/bin/activate"
echo "  asadb doctor"
echo "  asadb init --username admin --database-id main --filename data.asa"
echo "  asadb server"

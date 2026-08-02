#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
# Compile every shipped Prolog source and verify the intended runtime graph.
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
LOG=$(mktemp "${TMPDIR:-/tmp}/asadb-prolog-modules.XXXXXX")

cleanup() {
  rm -f "$LOG"
}
trap cleanup EXIT HUP INT TERM

cd "$ROOT"
find src -type f -name '*.pl' -print | sort | while IFS= read -r file
do
  if ! swipl -q -g "load_files('$file',[silent(true)]),list_undefined,halt" \
      >"$LOG" 2>&1; then
    cat "$LOG" >&2
    echo "FAIL: could not load $file" >&2
    exit 1
  fi
  if grep -F 'predicates below are not defined' "$LOG" >/dev/null; then
    cat "$LOG" >&2
    echo "FAIL: undefined predicate while loading $file" >&2
    exit 1
  fi
done

require_edge() {
  file=$1
  marker=$2
  if ! grep -F "$marker" "$file" >/dev/null; then
    echo "FAIL: runtime module edge missing: $file -> $marker" >&2
    exit 1
  fi
}

for module in \
  asadb_buffer_pool.pl asadb_pager.pl asadb_btree.pl asadb_config.pl \
  asadb_record_manager.pl asadb_metadata.pl asadb_mysql55_compat.pl \
  asadb_prolog_jit.pl asadb_schema.pl asadb_sql_frontend.pl
do
  require_edge src/asadb_core.pl "$module"
done

for module in \
  asadb_core.pl asadb_backup.pl asadb_config.pl asadb_interchange.pl \
  bridge/reservoir.pl
do
  require_edge src/asadb_web.pl "$module"
done

require_edge src/bridge/reservoir.pl karyawan.pl
require_edge src/asa_portable.pl asadb_web.pl
require_edge src/asadb_release.pl asadb.pl
require_edge scripts/asadb_guardian.sh \
  src/bridge/horsemen/contract/war/here/yoru_the_wardevil.pl

echo 'PASS: every shipped Prolog file loads and every runtime/build module has an entrypoint edge.'

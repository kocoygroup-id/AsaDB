#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/asadb-pack.XXXXXX")
PACK_HOME="$TMP_ROOT/packs"
STAGE="$TMP_ROOT/source"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

# The discoverability copy is intentionally checked: a version bump must not
# leave a stale manifest next to the user-authored pack directory.
cmp -s "$ROOT/pack.pl" "$ROOT/pack/pack.pl"

# Install from a detached complete source copy.  This exercises the same
# metadata and install path as a release without a development symlink writing
# status.db into the checked-out source tree.  It also works on minimal
# SWI-Prolog installations where library(archive) is deliberately not
# installed.
mkdir -p "$STAGE" "$PACK_HOME"
for path in \
  BENCHMARK_RESULTS.md BUGFIX_REPORT.txt CODE_OF_CONDUCT.md COMPATIBILITY.md \
  CONTRIBUTING.md DCO GNUmakefile GOVERNANCE.md INSTALL.md LICENSE \
  LICENSE_HISTORY.md OPEN_SOURCE_RELEASE_CHECKLIST.md README.md RELEASE.md \
  RELEASE_NOTES.md SECURITY.md SOURCE_CODE.md THIRD_PARTY_NOTICES.md \
  TRADEMARKS.md VERSION asadb.conf pack.pl \
  app bin docs examples flaskserver licenses pack prolog scripts src tests tools web
do
  cp -R "$ROOT/$path" "$STAGE/"
done
# A working tree may contain ignored Flask test/runtime residue.  Release and
# pack source must exercise only distributable files.
find "$STAGE/flaskserver" -type d \( -name __pycache__ -o -name .pytest_cache -o -name .venv -o -name var -o -name build -o -name '*.egg-info' \) -prune -exec rm -rf {} +
SOURCE_URI="file://$STAGE"

swipl -q -g "use_module(library(prolog_pack)), current_prolog_flag(version_data, swi(Major, _, _, _)), ( Major >= 10 -> DirectoryOption = pack_directory('$PACK_HOME') ; DirectoryOption = package_directory('$PACK_HOME') ), pack_install('$SOURCE_URI', [DirectoryOption, interactive(false), test(false)]), halt"
swipl -q -g "use_module(library(prolog_pack)), attach_packs('$PACK_HOME', [replace(true)]), pack_property(asadb, version('1.5.0')), halt"
INSTALLED="$PACK_HOME/asadb"
for required in \
  app/asadb.pl bin/asadb src/asadb.pl src/asadb_web.pl src/asa_portable.pl \
  scripts/run_asadb.sh scripts/run_panel.sh \
  web/index.html web/assets/app.js web/assets/app.legacy.js \
  examples/demo.sql docs/swi-prolog-pack.md prolog/asadb.pl tools/asadb_pack.pl tools/asadb_launcher.pl \
  flaskserver/pyproject.toml flaskserver/src/asadb_server/app.py \
  flaskserver/src/asadb_server/backend.py flaskserver/src/asadb_server/__main__.py \
  flaskserver/src/asadb_server/panel.py flaskserver/src/asadb_server/templates/login.html \
  flaskserver/src/asadb_server/templates/mode.html flaskserver/src/asadb_server/templates/logout.html \
  flaskserver/src/asadb_server/static/server.css flaskserver/src/asadb_server/static/logout.js \
  flaskserver/scripts/bootstrap_python.py flaskserver/requirements-bundled.txt flaskserver/docs/MERGE_AUDIT.md
do
  test -e "$INSTALLED/$required"
done
test -n "$(find "$INSTALLED/flaskserver/wheels" -maxdepth 1 -name 'pip-*.whl' -print -quit)"
# Some pack transports do not retain the executable bit of a shell launcher.
# Running the installed CLI through SWI-Prolog is transport-independent and
# verifies the complete installed engine rather than local file permissions.
(cd "$INSTALLED" &&
  swipl -q -s src/asadb.pl -- "$TMP_ROOT/pack-cli.asa" examples/demo.sql >/dev/null)
swipl -q -g "use_module(library(prolog_pack)), attach_packs('$PACK_HOME', [replace(true)]), use_module(library(asadb)), asadb:asadb_version('1.5.0'), asadb:asadb_parse_sql(\"SELECT 1;\", [_]), halt"
# Installed pack apps are resolved by SWI-Prolog itself.  This checks the exact
# end-user spelling instead of merely loading the entry point as a library.
SWIPL_PACK_PATH="$PACK_HOME" swipl -q asadb --help | grep -F 'AsaDB One Pack, Two Modes' >/dev/null
HELPER_VERSION=$(swipl -q -g "use_module(library(prolog_pack)), attach_packs('$PACK_HOME', [replace(true)])" -s "$INSTALLED/tools/asadb_pack.pl" -- version)
test "$HELPER_VERSION" = '1.5.0'
# The installed copy, not this checkout, must create its per-user runtime
# entirely from the bundled wheelhouse.  No pip index or source checkout is
# available to this command.
ASADB_HOME="$TMP_ROOT/asadb-home" \
  swipl -q -s "$INSTALLED/tools/asadb_launcher.pl" -- python setup >/dev/null
ASADB_HOME="$TMP_ROOT/asadb-home" \
  swipl -q -s "$INSTALLED/tools/asadb_launcher.pl" -- doctor --json | \
  grep -F '"ok": true' >/dev/null
swipl -q -g "use_module(library(prolog_pack)), attach_packs('$PACK_HOME', [replace(true)]), ( current_predicate(pack_remove/2) -> pack_remove(asadb, [pack_directory('$PACK_HOME'), interactive(false)]) ; pack_remove(asadb) ), halt"

test ! -e "$PACK_HOME/asadb"
printf '%s\n' 'PASS: AsaDB pack installs the complete CLI/panel/server source tree, builds its offline Python runtime, runs the CLI, reports its version, loads, and removes cleanly.'

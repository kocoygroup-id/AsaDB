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
  bin docs examples licenses pack prolog scripts src tests tools web
do
  cp -R "$ROOT/$path" "$STAGE/"
done
SOURCE_URI="file://$STAGE"

swipl -q -g "use_module(library(prolog_pack)), current_prolog_flag(version_data, swi(Major, _, _, _)), ( Major >= 10 -> DirectoryOption = pack_directory('$PACK_HOME') ; DirectoryOption = package_directory('$PACK_HOME') ), pack_install('$SOURCE_URI', [DirectoryOption, interactive(false), test(false)]), halt"
swipl -q -g "use_module(library(prolog_pack)), attach_packs('$PACK_HOME', [replace(true)]), pack_property(asadb, version('1.5.0')), halt"
INSTALLED="$PACK_HOME/asadb"
for required in \
  bin/asadb src/asadb.pl src/asadb_web.pl src/asa_portable.pl \
  scripts/run_asadb.sh scripts/run_panel.sh \
  web/index.html web/assets/app.js web/assets/app.legacy.js \
  examples/demo.sql docs/swi-prolog-pack.md prolog/asadb.pl
do
  test -e "$INSTALLED/$required"
done
# Some pack transports do not retain the executable bit of a shell launcher.
# Running the installed CLI through SWI-Prolog is transport-independent and
# verifies the complete installed engine rather than local file permissions.
(cd "$INSTALLED" &&
  swipl -q -s src/asadb.pl -- "$TMP_ROOT/pack-cli.asa" examples/demo.sql >/dev/null)
swipl -q -g "use_module(library(prolog_pack)), attach_packs('$PACK_HOME', [replace(true)]), use_module(library(asadb)), asadb:asadb_version('1.5.0'), asadb:asadb_parse_sql(\"SELECT 1;\", [_]), halt"
swipl -q -g "use_module(library(prolog_pack)), attach_packs('$PACK_HOME', [replace(true)]), ( current_predicate(pack_remove/2) -> pack_remove(asadb, [pack_directory('$PACK_HOME'), interactive(false)]) ; pack_remove(asadb) ), halt"

test ! -e "$PACK_HOME/asadb"
printf '%s\n' 'PASS: AsaDB pack installs the complete CLI/panel source tree, runs the CLI, reports its version, loads, and removes cleanly.'

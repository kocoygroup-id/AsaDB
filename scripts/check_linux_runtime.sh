#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
VERSION=$(sed -n '1p' "$ROOT/VERSION")
OS=$(uname -s 2>/dev/null || printf '%s' unknown)
ARCH=$(uname -m 2>/dev/null || printf '%s' unknown)

printf 'AsaDB %s Linux x86_64 runtime check\n' "$VERSION"
printf 'OS: %s\nArchitecture: %s\n' "$OS" "$ARCH"

if [ "$OS" != Linux ]; then
  echo "FAIL: paket ini menargetkan Linux." >&2
  exit 1
fi

case "$ARCH" in
  x86_64|amd64) ;;
  *)
    echo "FAIL: paket ini menargetkan x86_64; arsitektur terdeteksi: $ARCH" >&2
    exit 1
    ;;
esac

if ! command -v swipl >/dev/null 2>&1; then
  echo "FAIL: swipl tidak ditemukan di PATH." >&2
  echo "4MLinux tidak menyediakan package manager umum; pasang/build SWI-Prolog dahulu." >&2
  echo "Lihat INSTALL.md untuk langkah dan dependensi runtime." >&2
  exit 1
fi

printf 'Runtime: '
swipl --version

# `swipl asadb` is a SWI-Prolog pack application.  The app search path used by
# AsaDB first became available in 9.1.18, so accepting an older runtime here
# would make the documented one-command start fail after an otherwise healthy
# dependency check.
if ! swipl -q -g "current_prolog_flag(version_data, swi(Major, Minor, Patch, _)), ( Major > 9 ; Major =:= 9, ( Minor > 1 ; Minor =:= 1, Patch >= 18 ) ), halt"; then
  echo "FAIL: AsaDB requires SWI-Prolog 9.1.18 or newer for 'swipl asadb'." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 tidak ditemukan; scripts/run_panel.sh membutuhkan Python 3.10-3.13 untuk portal login." >&2
  exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
case "$PYTHON_VERSION" in
  3.10|3.11|3.12|3.13) ;;
  *)
    echo "FAIL: portal login membutuhkan Python 3.10-3.13; terdeteksi $PYTHON_VERSION." >&2
    exit 1
    ;;
esac
printf 'Python portal runtime: %s\n' "$PYTHON_VERSION"

cd "$ROOT"

if ! swipl -q -g "use_module(library(assoc)),use_module(library(crypto)),use_module(library(uuid)),use_module(library(csv)),use_module(library(sgml)),use_module(library(zip)),use_module(library(http/thread_httpd)),use_module(library(http/http_dispatch)),use_module(library(http/http_parameters)),use_module(library(http/http_client)),use_module(library(http/http_multipart_plugin)),use_module(library(http/json)),use_module(library(http/http_stream)),halt"; then
  echo "FAIL: modul SWI-Prolog untuk core, interchange, HTTP, crypto, atau UUID tidak lengkap." >&2
  exit 1
fi

if ! swipl -q -g "current_predicate(thread_create/3),current_predicate(message_queue_create/1),halt"; then
  echo "FAIL: dukungan thread/message queue SWI-Prolog tidak tersedia." >&2
  exit 1
fi

if ! swipl -q -g "load_files('src/asadb_core.pl',[silent(true)]),load_files('src/asadb_interchange.pl',[silent(true)]),load_files('src/bridge/reservoir.pl',[silent(true)]),load_files('src/bridge/horsemen/contract/war/here/yoru_the_wardevil.pl',[silent(true)]),load_files('src/asadb_web.pl',[silent(true)]),list_undefined,halt"; then
  echo "FAIL: core, interchange, Reservoir, Process Guardian, atau backend web AsaDB tidak dapat dimuat." >&2
  exit 1
fi

echo "PASS: runtime, Python portal, core, Reservoir, dan backend web AsaDB siap dipakai."

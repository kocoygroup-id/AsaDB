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

cd "$ROOT"

if ! swipl -q -g "use_module(library(assoc)),use_module(library(crypto)),use_module(library(uuid)),use_module(library(http/thread_httpd)),use_module(library(http/http_dispatch)),use_module(library(http/http_parameters)),use_module(library(http/http_client)),use_module(library(http/http_multipart_plugin)),use_module(library(http/json)),use_module(library(http/http_stream)),halt"; then
  echo "FAIL: modul SWI-Prolog untuk core, HTTP, crypto, atau UUID tidak lengkap." >&2
  exit 1
fi

if ! swipl -q -g "current_predicate(thread_create/3),current_predicate(message_queue_create/1),halt"; then
  echo "FAIL: dukungan thread/message queue SWI-Prolog tidak tersedia." >&2
  exit 1
fi

if ! swipl -q -g "load_files('src/asadb_core.pl',[silent(true)]),load_files('src/bridge/reservoir.pl',[silent(true)]),load_files('src/asadb_web.pl',[silent(true)]),halt"; then
  echo "FAIL: core, Reservoir, atau backend web AsaDB tidak dapat dimuat." >&2
  exit 1
fi

echo "PASS: runtime, core, Reservoir, dan backend web AsaDB siap dipakai."

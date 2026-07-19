#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
OS=$(uname -s 2>/dev/null || printf '%s' unknown)
ARCH=$(uname -m 2>/dev/null || printf '%s' unknown)

if [ "$OS" != Linux ]; then
  echo "This target must be packaged on Linux; detected: $OS" >&2
  exit 2
fi

case "$ARCH" in
  x86_64|amd64) ;;
  *)
    echo "This target is linux-x86_64; detected architecture: $ARCH" >&2
    exit 2
    ;;
esac

ASADB_RELEASE_PLATFORM=linux-x86_64
export ASADB_RELEASE_PLATFORM
exec "$ROOT/scripts/build_source_release.sh"

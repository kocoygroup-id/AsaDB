#!/bin/sh
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
CONTRACT="$ROOT/scripts/realtime_release_contract.txt"

check_marker() {
  File=$1
  Marker=$2
  if ! grep -F "$Marker" "$File" >/dev/null; then
    echo "Realtime release contract marker is missing from ${File#"$ROOT"/}: $Marker" >&2
    exit 1
  fi
}

while IFS='|' read -r Scope Marker
do
  case "$Scope" in
    ''|'#'*) continue ;;
    bundle)
      check_marker "$ROOT/web/assets/app.js" "$Marker"
      check_marker "$ROOT/web/assets/app.legacy.js" "$Marker"
      ;;
    markup)
      check_marker "$ROOT/web/index.html" "$Marker"
      ;;
    backend)
      check_marker "$ROOT/src/asadb_web.pl" "$Marker"
      ;;
    *)
      echo "Unknown realtime release contract scope: $Scope" >&2
      exit 2
      ;;
  esac
done < "$CONTRACT"

echo "PASS: modern, legacy, markup, and backend realtime release contracts are synchronized."

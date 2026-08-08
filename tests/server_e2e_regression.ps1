# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("asadb-server-e2e-" + [guid]::NewGuid())
$env:ASADB_HOME = Join-Path $TempRoot 'home'
$env:ASADB_REPO_ROOT = $Root

# Exercise the end-user pack spelling before using the source launcher.
Push-Location $Root
try {
  swipl pack install .
  swipl asadb --help

  py -3 (Join-Path $Root 'flaskserver\scripts\bootstrap_python.py') setup
  $Python = Join-Path $env:ASADB_HOME 'python-env\Scripts\python.exe'
  if (-not (Test-Path $Python)) {
    throw "Offline Python bootstrap did not create $Python"
  }
  $env:PYTHONPATH = Join-Path $Root 'flaskserver\src'
  & $Python (Join-Path $Root 'flaskserver\tests\hardening_regression.py')
  & $Python (Join-Path $Root 'flaskserver\tests\e2e_prolog_server.py')
  py -3 (Join-Path $Root 'flaskserver\scripts\bootstrap_python.py') doctor --json
} finally {
  Pop-Location
}

Write-Output 'PASS: Windows pack install, offline wheelhouse, and real Flask-to-SWI-Prolog server E2E regression.'

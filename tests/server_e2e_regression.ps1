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
  $PackRoot = Join-Path $env:LOCALAPPDATA 'swi-prolog\pack'
  New-Item -ItemType Directory -Path $PackRoot -Force | Out-Null
  @('Y') | swipl pack install .
  if ($LASTEXITCODE -ne 0) {
    throw "swipl pack install . failed with exit code $LASTEXITCODE"
  }
  swipl asadb --help
  if ($LASTEXITCODE -ne 0) {
    throw "swipl asadb --help failed with exit code $LASTEXITCODE"
  }

  $PythonHost = (Get-Command python -ErrorAction Stop).Source
  & $PythonHost (Join-Path $Root 'flaskserver\scripts\bootstrap_python.py') setup
  if ($LASTEXITCODE -ne 0) {
    throw "Offline Python bootstrap failed with exit code $LASTEXITCODE"
  }
  $Python = Join-Path $env:ASADB_HOME 'python-env\Scripts\python.exe'
  if (-not (Test-Path $Python)) {
    throw "Offline Python bootstrap did not create $Python"
  }
  Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue
  & $Python (Join-Path $Root 'flaskserver\tests\hardening_regression.py')
  if ($LASTEXITCODE -ne 0) {
    throw "Server hardening regression failed with exit code $LASTEXITCODE"
  }
  & $Python (Join-Path $Root 'flaskserver\tests\e2e_prolog_server.py')
  if ($LASTEXITCODE -ne 0) {
    throw "Server E2E regression failed with exit code $LASTEXITCODE"
  }
  & $PythonHost (Join-Path $Root 'flaskserver\scripts\bootstrap_python.py') doctor --json
  if ($LASTEXITCODE -ne 0) {
    throw "Server doctor failed with exit code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}

Write-Output 'PASS: Windows pack install, offline wheelhouse, and real Flask-to-SWI-Prolog server E2E regression.'

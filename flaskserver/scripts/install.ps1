$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root

py -m venv .venv
& .\.venv\Scripts\python.exe -m pip install --upgrade pip
& .\.venv\Scripts\python.exe -m pip install -e ".[dev]"

Write-Host ""
Write-Host "Installed. Set ASADB_REPO_ROOT to the AsaDB repository root, then run:"
Write-Host "  .\.venv\Scripts\Activate.ps1"
Write-Host "  asadb doctor"
Write-Host "  asadb init --username admin --database-id main --filename data.asa"
Write-Host "  asadb server"

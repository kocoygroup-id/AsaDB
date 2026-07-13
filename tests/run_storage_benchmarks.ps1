# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
param(
  [int[]]$Rows = @(10000, 50000, 100000),
  [string]$OutputDirectory = "tests\benchmark-results"
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Output = Join-Path $Root $OutputDirectory
New-Item -ItemType Directory -Force -Path $Output | Out-Null

$summary = @()
foreach ($rowCount in $Rows) {
  $stdout = Join-Path $Output "storage-$rowCount.stdout.log"
  $stderr = Join-Path $Output "storage-$rowCount.stderr.log"
  Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue

  $arguments = @("-q", "-s", "tests\stress_100k.pl", "--", "$rowCount")
  $process = Start-Process -FilePath "swipl.exe" -ArgumentList $arguments `
    -WorkingDirectory $Root -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr -PassThru -WindowStyle Hidden

  $peakBytes = 0L
  $started = Get-Date
  while (-not $process.HasExited) {
    $process.Refresh()
    if ($process.PeakWorkingSet64 -gt $peakBytes) {
      $peakBytes = $process.PeakWorkingSet64
    }
    Start-Sleep -Milliseconds 250
  }
  $process.Refresh()
  if ($process.PeakWorkingSet64 -gt $peakBytes) {
    $peakBytes = $process.PeakWorkingSet64
  }

  $elapsed = [math]::Round(((Get-Date) - $started).TotalSeconds, 3)
  $passed = (Select-String -LiteralPath $stdout -Pattern "STRESS $rowCount PASS" -Quiet)
  $summary += [pscustomobject]@{
    rows = $rowCount
    passed = $passed
    elapsed_seconds = $elapsed
    peak_working_set_mb = [math]::Round($peakBytes / 1MB, 1)
    stdout = $stdout
    stderr = $stderr
  }
  if (-not $passed) {
    throw "Storage benchmark $rowCount failed. See $stdout and $stderr."
  }
}

$summary | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Output "summary.json") -Encoding UTF8
$summary | Format-Table -AutoSize

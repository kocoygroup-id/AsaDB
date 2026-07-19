# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
$ErrorActionPreference = "Stop"

$Root = [string](Resolve-Path (Join-Path $PSScriptRoot ".."))
$Contract = Join-Path $Root "scripts\realtime_release_contract.txt"

function Assert-Marker {
  param([string]$File, [string]$Marker)

  $Content = [System.IO.File]::ReadAllText($File)
  if (-not $Content.Contains($Marker)) {
    $Relative = $File
    if ($File.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
      $Relative = $File.Substring($Root.Length).TrimStart([char[]]@("\", "/"))
    }
    throw "Realtime release contract marker is missing from ${Relative}: $Marker"
  }
}

foreach ($Line in [System.IO.File]::ReadAllLines($Contract)) {
  if ([string]::IsNullOrWhiteSpace($Line) -or $Line.StartsWith("#")) {
    continue
  }

  $Separator = $Line.IndexOf("|")
  if ($Separator -lt 1) {
    throw "Invalid realtime release contract line: $Line"
  }

  $Scope = $Line.Substring(0, $Separator)
  $Marker = $Line.Substring($Separator + 1)
  switch ($Scope) {
    "bundle" {
      Assert-Marker (Join-Path $Root "web\assets\app.js") $Marker
      Assert-Marker (Join-Path $Root "web\assets\app.legacy.js") $Marker
    }
    "markup" {
      Assert-Marker (Join-Path $Root "web\index.html") $Marker
    }
    "backend" {
      Assert-Marker (Join-Path $Root "src\asadb_web.pl") $Marker
    }
    default {
      throw "Unknown realtime release contract scope: $Scope"
    }
  }
}

Write-Host "PASS: modern, legacy, markup, and backend realtime release contracts are synchronized."

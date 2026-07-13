# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
param(
  [string]$Name = "AsaDB",
  [switch]$SkipRuntime
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Dist = Join-Path $Root "dist\$Name"
$Build = Join-Path $Root "build"
$Exe = Join-Path $Dist "$Name.exe"
$Icon = Join-Path $Dist "$Name.ico"
$Emulator = Join-Path $Build "$Name-emulator.exe"
$Logo = Join-Path $Root "web\assets\asadb-logo.png"

function To-PrologPath([string]$Path) {
  return ($Path -replace "\\", "/") -replace "'", "''"
}

function New-AsaIcon {
  param([string]$SourcePng, [string]$OutIco)

  Add-Type -AssemblyName System.Drawing
  $sizes = @(16, 24, 32, 48, 64, 128, 256)
  $source = [System.Drawing.Bitmap]::FromFile($SourcePng)
  $images = New-Object System.Collections.Generic.List[object]

  try {
    foreach ($size in $sizes) {
      $canvas = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
      $graphics = [System.Drawing.Graphics]::FromImage($canvas)
      $graphics.Clear([System.Drawing.Color]::Transparent)
      $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
      $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

      $scale = [Math]::Min(($size - 2) / $source.Width, ($size - 2) / $source.Height)
      $width = [Math]::Max(1, [int]($source.Width * $scale))
      $height = [Math]::Max(1, [int]($source.Height * $scale))
      $x = [int](($size - $width) / 2)
      $y = [int](($size - $height) / 2)
      $graphics.DrawImage($source, $x, $y, $width, $height)
      $graphics.Dispose()

      $stream = New-Object System.IO.MemoryStream
      $canvas.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
      $images.Add([pscustomobject]@{ Size = $size; Bytes = $stream.ToArray() }) | Out-Null
      $stream.Dispose()
      $canvas.Dispose()
    }
  } finally {
    $source.Dispose()
  }

  $fs = [System.IO.File]::Create($OutIco)
  $writer = New-Object System.IO.BinaryWriter $fs
  try {
    $writer.Write([UInt16]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]$images.Count)
    $offset = 6 + (16 * $images.Count)
    foreach ($img in $images) {
      $iconSize = if ($img.Size -eq 256) { 0 } else { $img.Size }
      $writer.Write([byte]$iconSize)
      $writer.Write([byte]$iconSize)
      $writer.Write([byte]0)
      $writer.Write([byte]0)
      $writer.Write([UInt16]1)
      $writer.Write([UInt16]32)
      $writer.Write([UInt32]$img.Bytes.Length)
      $writer.Write([UInt32]$offset)
      $offset += $img.Bytes.Length
    }
    foreach ($img in $images) {
      $writer.Write($img.Bytes)
    }
  } finally {
    $writer.Dispose()
    $fs.Dispose()
  }
}

function Set-ExeIcon {
  param([string]$ExePath, [string]$IcoPath)

  $code = @'
using System;
using System.IO;
using System.Runtime.InteropServices;

public static class IconResourceUpdater {
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  static extern IntPtr BeginUpdateResource(string pFileName, bool bDeleteExistingResources);

  [DllImport("kernel32.dll", SetLastError=true)]
  static extern bool UpdateResource(IntPtr hUpdate, IntPtr lpType, IntPtr lpName, ushort wLanguage, byte[] lpData, uint cbData);

  [DllImport("kernel32.dll", SetLastError=true)]
  static extern bool EndUpdateResource(IntPtr hUpdate, bool fDiscard);

  static IntPtr I(int value) { return new IntPtr(value); }

  public static void Apply(string exePath, string icoPath) {
    byte[] ico = File.ReadAllBytes(icoPath);
    using (BinaryReader reader = new BinaryReader(new MemoryStream(ico))) {
      ushort reserved = reader.ReadUInt16();
      ushort type = reader.ReadUInt16();
      ushort count = reader.ReadUInt16();
      if (reserved != 0 || type != 1 || count == 0) throw new InvalidDataException("Invalid ICO file.");

      byte[] group = new byte[6 + count * 14];
      using (BinaryWriter writer = new BinaryWriter(new MemoryStream(group))) {
        writer.Write((ushort)0);
        writer.Write((ushort)1);
        writer.Write(count);

        IntPtr handle = BeginUpdateResource(exePath, false);
        if (handle == IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        bool ok = false;
        try {
          for (ushort id = 1; id <= count; id++) {
            byte width = reader.ReadByte();
            byte height = reader.ReadByte();
            byte colors = reader.ReadByte();
            byte entryReserved = reader.ReadByte();
            ushort planes = reader.ReadUInt16();
            ushort bitCount = reader.ReadUInt16();
            uint bytesInRes = reader.ReadUInt32();
            uint imageOffset = reader.ReadUInt32();

            long here = reader.BaseStream.Position;
            reader.BaseStream.Position = imageOffset;
            byte[] image = reader.ReadBytes((int)bytesInRes);
            reader.BaseStream.Position = here;

            if (!UpdateResource(handle, I(3), I(id), 0, image, (uint)image.Length)) {
              throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            }

            writer.Write(width);
            writer.Write(height);
            writer.Write(colors);
            writer.Write(entryReserved);
            writer.Write(planes);
            writer.Write(bitCount);
            writer.Write(bytesInRes);
            writer.Write(id);
          }

          if (!UpdateResource(handle, I(14), I(1), 0, group, (uint)group.Length)) {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
          }

          ok = true;
        } finally {
          if (!EndUpdateResource(handle, !ok)) {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
          }
        }
      }
    }
  }
}
'@

  if (-not ("IconResourceUpdater" -as [type])) {
    Add-Type -TypeDefinition $code
  }
  [IconResourceUpdater]::Apply($ExePath, $IcoPath)
}

New-Item -ItemType Directory -Force -Path $Build | Out-Null
if (Test-Path $Dist) {
  Remove-Item $Dist -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $Dist | Out-Null

New-AsaIcon -SourcePng $Logo -OutIco $Icon
$SwiplExe = (Get-Command swipl).Source
Copy-Item -Path $SwiplExe -Destination $Emulator -Force
Set-ExeIcon -ExePath $Emulator -IcoPath $Icon

$ExeForProlog = To-PrologPath $Exe
$EmulatorForProlog = To-PrologPath $Emulator
$Goal = "['src/asa_portable.pl'], qsave_program('$ExeForProlog', [goal(asa_entry), toplevel(asa_entry), stand_alone(true), emulator('$EmulatorForProlog')]), halt."
Push-Location $Root
try {
  swipl -q -g $Goal
} finally {
  Pop-Location
}

Copy-Item -Path (Join-Path $Root "web") -Destination (Join-Path $Dist "web") -Recurse -Force
Copy-Item -Path (Join-Path $Root "asadb.conf") -Destination $Dist -Force
Copy-Item -Path (Join-Path $Root "LICENSE") -Destination $Dist -Force
Copy-Item -Path (Join-Path $Root "README.md") -Destination $Dist -Force
Copy-Item -Path (Join-Path $Root "SOURCE_CODE.md") -Destination $Dist -Force
Copy-Item -Path (Join-Path $Root "THIRD_PARTY_NOTICES.md") -Destination $Dist -Force
Copy-Item -Path (Join-Path $Root "TRADEMARKS.md") -Destination $Dist -Force

$StressDir = Join-Path $Root "Stress Test"
if (Test-Path $StressDir) {
  Copy-Item -Path $StressDir -Destination (Join-Path $Dist "Stress Test") -Recurse -Force
}

if (-not $SkipRuntime) {
  $SwiplRoot = Split-Path (Split-Path $SwiplExe -Parent) -Parent
  Copy-Item -Path (Join-Path $SwiplRoot "boot.prc") -Destination $Dist -Force
  Copy-Item -Path (Join-Path $SwiplRoot "library") -Destination (Join-Path $Dist "library") -Recurse -Force
  Copy-Item -Path (Join-Path $SwiplRoot "bin") -Destination (Join-Path $Dist "bin") -Recurse -Force
  Copy-Item -Path (Join-Path $SwiplRoot "bin\*.dll") -Destination $Dist -Force
  $LicenseDir = Join-Path $Dist "licenses"
  New-Item -ItemType Directory -Force -Path $LicenseDir | Out-Null
  Copy-Item -Path (Join-Path $SwiplRoot "LICENSE") -Destination (Join-Path $LicenseDir "SWI-Prolog-LICENSE.txt") -Force
}

Write-Host "Built $Exe"
Write-Host "Run: $Exe"

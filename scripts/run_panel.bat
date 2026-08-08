REM Copyright (C) 2026 Kocoy Group and AsaDB contributors
REM SPDX-License-Identifier: GPL-3.0-only
@echo off
set DB_FILE=%1
set PORT=%2
if "%DB_FILE%"=="" set DB_FILE=data.asa
if "%PORT%"=="" set PORT=8088
cd /d "%~dp0\.."
for %%I in ("%DB_FILE%") do (
  set "DB_DIR=%%~dpI"
  set "DB_NAME=%%~nxI"
)
swipl -q -s tools\asadb_launcher.pl -- start --database "%DB_NAME%" --data-dir "%DB_DIR%" --port "%PORT%"

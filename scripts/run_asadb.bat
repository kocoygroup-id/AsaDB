REM Copyright (C) 2026 Kocoy Group and AsaDB contributors
REM SPDX-License-Identifier: GPL-3.0-only
@echo off
set DB_FILE=%1
set SQL_FILE=%2
if "%DB_FILE%"=="" set DB_FILE=data.asa
cd /d %~dp0\..
if "%SQL_FILE%"=="" (
  swipl -q -s src/asadb.pl -- %DB_FILE%
) else (
  swipl -q -s src/asadb.pl -- %DB_FILE% %SQL_FILE%
)

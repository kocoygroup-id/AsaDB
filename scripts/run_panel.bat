REM Copyright (C) 2026 Kocoy Group and AsaDB contributors
REM SPDX-License-Identifier: GPL-3.0-only
@echo off
set DB_FILE=%1
set PORT=%2
if "%DB_FILE%"=="" set DB_FILE=data.asa
if "%PORT%"=="" set PORT=8088
cd /d %~dp0\..
swipl -q -s src/asadb_web.pl -- %DB_FILE% %PORT%

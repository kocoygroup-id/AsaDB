@echo off
setlocal
cd /d "%~dp0app"
"AsA.exe" panel --no-browser "..\data\asadb.asa" 8088
endlocal

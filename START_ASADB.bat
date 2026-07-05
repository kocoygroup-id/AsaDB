@echo off
setlocal
cd /d "%~dp0app"
start "AsaDB v1.0.0" "AsA.exe" panel "..\data\asadb.asa" 8088
echo AsaDB v1.0.0 starting at http://127.0.0.1:8088
echo If the browser does not open, open that URL manually.
endlocal

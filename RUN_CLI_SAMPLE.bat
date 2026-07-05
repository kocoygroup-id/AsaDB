@echo off
setlocal
cd /d "%~dp0app"
"AsA.exe" cli "..\data\sample-run.asa" "..\samples\feature-tour.sql"
pause
endlocal

@echo off
setlocal
cd /d "%~dp0\..\..\apps\oracle-sync"
"%~dp0runtime\node.exe" "%~dp0\..\..\apps\oracle-sync\node_modules\tsx\dist\cli.mjs" --env-file=.env src\cli.ts sync:once
exit /b %errorlevel%

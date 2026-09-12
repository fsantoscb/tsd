@echo off
setlocal
cd /d "%~dp0\..\..\apps\web"
"%~dp0runtime\node.exe" "%~dp0\..\..\apps\web\node_modules\next\dist\bin\next" start
exit /b %errorlevel%

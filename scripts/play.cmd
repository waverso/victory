@echo off
rem scripts\play.cmd [play.ps1 switches], e.g. scripts\play.cmd -Fit -Height 576
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0play.ps1" %*
echo.
pause

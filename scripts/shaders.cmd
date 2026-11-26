@echo off
setlocal
cd /d "%~dp0.."
if not exist logs mkdir logs
set LOG=logs\shaders.log
echo [shaders] start %DATE% %TIME% > "%LOG%"
target\diag\victory.exe shaders >> "%LOG%" 2>&1
echo [shaders] exit %ERRORLEVEL% %DATE% %TIME% >> "%LOG%"
findstr /c:"shaders in the cache" /c:"[shaders]" "%LOG%"
pause

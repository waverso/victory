@echo off
setlocal
cd /d "%~dp0.."
if not exist logs mkdir logs
set LOG=logs\build.log
echo [build] start %DATE% %TIME% > "%LOG%"
cargo build --locked --profile diag -p victory --features diagnostics >> "%LOG%" 2>&1
echo [build] exit %ERRORLEVEL% %DATE% %TIME% >> "%LOG%"
findstr /c:"error" /c:"Finished" /c:"[build]" "%LOG%"
pause

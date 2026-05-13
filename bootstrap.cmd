@echo off
REM ============================================================
REM  PM Hackathon Bootstrap — local CMD launcher
REM
REM  ONLY needed if you've already cloned/extracted the repo and
REM  want to launch from a local folder. For the seamless path,
REM  paste this in a CMD or PowerShell window (no clone required):
REM
REM    powershell -NoProfile -Command "iex (irm 'https://raw.githubusercontent.com/vamckMS/pm-hackathon-bootscript/main/bootstrap.ps1')"
REM ============================================================
setlocal
cd /d "%~dp0"

echo.
echo [PM-Bootstrap] Unblocking files (clearing Mark-of-the-Web)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Get-ChildItem -Path '%~dp0' -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue"

echo [PM-Bootstrap] Launching via ScriptBlock (GPO-immune)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "& ([ScriptBlock]::Create((Get-Content -Raw -LiteralPath '%~dp0bootstrap.ps1')))" %*
set RC=%ERRORLEVEL%

echo.
echo [PM-Bootstrap] Done. Exit code: %RC%
echo Press any key to close...
pause >nul
endlocal & exit /b %RC%

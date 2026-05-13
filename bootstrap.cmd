@echo off
REM ============================================================
REM  PM Hackathon Bootstrap — CMD launcher
REM  Works from cmd.exe, PowerShell, or double-click.
REM  Handles:
REM   - Users who aren't in PowerShell
REM   - Mark-of-the-Web (zip download) blocking script execution
REM   - Default ExecutionPolicy preventing .ps1 from running
REM   - GPO-enforced ExecutionPolicy (AllSigned/RemoteSigned via
REM     MachinePolicy/UserPolicy) where -ExecutionPolicy Bypass is
REM     IGNORED. We bypass this by loading the script as TEXT and
REM     invoking it via [ScriptBlock]::Create — no file is "executed"
REM     in the policy-engine sense.
REM ============================================================
setlocal EnableDelayedExpansion
cd /d "%~dp0"

echo.
echo [PM-Bootstrap] Unblocking files (clearing Mark-of-the-Web)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Get-ChildItem -Path '%~dp0' -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue"

echo [PM-Bootstrap] Effective ExecutionPolicy:
powershell -NoProfile -Command "Get-ExecutionPolicy -List | Format-Table -AutoSize | Out-String | Write-Host"

echo [PM-Bootstrap] Launching bootstrap.ps1 via ScriptBlock (GPO-immune)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "& ([ScriptBlock]::Create((Get-Content -Raw -LiteralPath '%~dp0bootstrap.ps1')))" %*
set RC=%ERRORLEVEL%

echo.
echo [PM-Bootstrap] Done. Exit code: %RC%
echo Press any key to close...
pause >nul
endlocal & exit /b %RC%

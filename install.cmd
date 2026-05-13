@echo off
REM ============================================================
REM  PM Hackathon Bootstrap — zero-prereq web installer
REM  Downloads this repo as a zip (no git required), extracts,
REM  unblocks, and launches bootstrap.ps1.
REM
REM  Usage from CMD or PowerShell:
REM    curl -L -o %TEMP%\pmboot.cmd https://raw.githubusercontent.com/vamckMS/pm-hackathon-bootscript/main/install.cmd ^&^& %TEMP%\pmboot.cmd
REM ============================================================
setlocal
set "REPO=vamckMS/pm-hackathon-bootscript"
set "BRANCH=main"
set "WORK=%TEMP%\pm-hackathon-bootscript"
set "ZIP=%TEMP%\pm-hackathon-bootscript.zip"

echo [PM-Bootstrap] Downloading latest from %REPO%@%BRANCH%...
if exist "%ZIP%"  del /q "%ZIP%"
if exist "%WORK%" rmdir /s /q "%WORK%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/%REPO%/archive/refs/heads/%BRANCH%.zip' -OutFile '%ZIP%'"
if errorlevel 1 (
  echo [PM-Bootstrap] ERROR: Download failed. Check network/proxy and try again.
  goto :end
)

echo [PM-Bootstrap] Extracting...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%WORK%' -Force"
if errorlevel 1 goto :end

echo [PM-Bootstrap] Unblocking files...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Get-ChildItem -Path '%WORK%' -Recurse -File | Unblock-File"

set "ROOT=%WORK%\pm-hackathon-bootscript-%BRANCH%"
if not exist "%ROOT%\bootstrap.cmd" (
  echo [PM-Bootstrap] ERROR: bootstrap.cmd not found at %ROOT%
  goto :end
)

echo [PM-Bootstrap] Launching bootstrap.cmd...
call "%ROOT%\bootstrap.cmd" %*

:end
endlocal

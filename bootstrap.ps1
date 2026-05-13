<#
.SYNOPSIS
    PM Hackathon Bootstrap — installs everything a PM needs to participate in the
    Microsoft PM hackathon on a clean Windows machine.

.DESCRIPTION
    Idempotent. Self-elevates to admin. Uses winget (primary) with Chocolatey (fallback).
    Installs: Git, Node LTS, Python 3, GitHub CLI, Windows Terminal, PowerShell 7,
    VS Code + extensions (Copilot, Copilot Chat, Copilot CLI, Python, PowerShell,
    Azure MCP Server, ...), the gh-copilot extension, validates the GitHub<->Microsoft
    link for unlimited Copilot tokens, and installs Agency Copilot.

.PARAMETER WhatIf
    Detect-only pass — does not change the system. Use to preview what would happen.

.PARAMETER Force
    One or more module IDs to force-reinstall (bypass idempotency). Use 'all' for everything.
    Examples: -Force 'vscode-extensions','agency-copilot'   or   -Force 'all'

.PARAMETER GithubUsername
    Provide your GitHub username non-interactively. If omitted, the script prompts.

.PARAMETER SkipGhValidation
    Skip the GitHub<->Microsoft link validation (NOT recommended).

.PARAMETER AgencyTag
    Optional pin for the Agency Copilot FALLBACK install path. By default the script
    resolves and downloads the LATEST release from the repo. Only set this to roll back.

.EXAMPLE
    .\bootstrap.ps1

.EXAMPLE
    .\bootstrap.ps1 -WhatIf

.EXAMPLE
    .\bootstrap.ps1 -Force vscode-extensions -GithubUsername alice-msft

.NOTES
    Logs:  %LOCALAPPDATA%\PMHackathonBootstrap\logs\
    State: %LOCALAPPDATA%\PMHackathonBootstrap\state\
#>

[CmdletBinding()]
param(
    [switch]$WhatIf,
    [string[]]$Force = @(),
    [string]$GithubUsername,
    [switch]$SkipGhValidation,
    [string]$AgencyTag = ''
)

# ---------- Self-elevate ----------
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "Re-launching elevated..." -ForegroundColor Yellow
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"")
    if ($WhatIf)                  { $argList += '-WhatIf' }
    if ($Force)                   { $argList += @('-Force') + $Force }
    if ($GithubUsername)          { $argList += @('-GithubUsername', $GithubUsername) }
    if ($SkipGhValidation)        { $argList += '-SkipGhValidation' }
    if ($AgencyTag)               { $argList += @('-AgencyTag', $AgencyTag) }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    return
}

$ErrorActionPreference = 'Stop'
Set-ExecutionPolicy Bypass -Scope Process -Force | Out-Null

# ---------- Load modules ----------
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$mod  = Join-Path $here 'modules'
$cfg  = Join-Path $here 'config\extensions.json'

Import-Module (Join-Path $mod 'Common.psm1') -Force
. (Join-Path $mod 'Install-Prereqs.ps1')
. (Join-Path $mod 'Install-CoreTools.ps1')
. (Join-Path $mod 'Install-Terminal.ps1')
. (Join-Path $mod 'Install-VSCode.ps1')
. (Join-Path $mod 'Install-GhCli.ps1')
. (Join-Path $mod 'Test-GithubLink.ps1')
. (Join-Path $mod 'Install-AgencyCopilot.ps1')
. (Join-Path $mod 'Show-Summary.ps1')

Initialize-Bootstrap -WhatIfMode:$WhatIf -Force $Force
Assert-Admin

try {
    Invoke-PrereqsStep
    Invoke-CoreToolsStep
    Invoke-TerminalStep
    Invoke-VSCodeStep -ExtensionsConfigPath $cfg
    Invoke-GhCopilotExtensionStep
    $linkOk = Invoke-GhAuthValidateStep -ExpectedUsername $GithubUsername -SkipValidation:$SkipGhValidation
    if ($linkOk -or $SkipGhValidation) {
        Invoke-AgencyCopilotStep -FallbackTag $AgencyTag
    } else {
        Add-Result -Module 'agency-copilot' -Status 'Skipped' -Detail 'Skipped because GH<->MS link validation failed. Fix that, then re-run.'
    }
} catch {
    Write-Log "Fatal: $($_.Exception.Message)" 'ERROR'
} finally {
    $code = Show-Summary
    Stop-Bootstrap
    exit $code
}

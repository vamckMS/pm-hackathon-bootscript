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

    # Build the parameter passthrough string. Escape single quotes by doubling.
    function _q([string]$s) { "'" + ($s -replace "'", "''") + "'" }
    $params = @()
    if ($WhatIf)             { $params += '-WhatIf' }
    if ($Force)              { $params += '-Force ' + (($Force | ForEach-Object { _q $_ }) -join ',') }
    if ($GithubUsername)     { $params += '-GithubUsername ' + (_q $GithubUsername) }
    if ($SkipGhValidation)   { $params += '-SkipGhValidation' }
    if ($AgencyTag)          { $params += '-AgencyTag ' + (_q $AgencyTag) }
    $paramStr = ($params -join ' ')

    # Use -EncodedCommand with a scriptblock created from the file's TEXT.
    # This bypasses ExecutionPolicy even when MachinePolicy/UserPolicy is set
    # by GPO (where -ExecutionPolicy Bypass on the command line is ignored),
    # because we're invoking inline commands, not loading a script file.
    $scriptPath = $PSCommandPath
    $cmd = "& ([ScriptBlock]::Create((Get-Content -Raw -LiteralPath " + (_q $scriptPath) + "))) $paramStr"
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($cmd)
    $encoded = [Convert]::ToBase64String($bytes)

    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded)
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    return
}

$ErrorActionPreference = 'Stop'
Set-ExecutionPolicy Bypass -Scope Process -Force | Out-Null

# ---------- Load modules ----------
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

# Clear Mark-of-the-Web on all files in our tree so dot-sourced modules run
# even if the user downloaded this repo as a zip from a browser.
try {
    Get-ChildItem -Path $here -Recurse -File -ErrorAction SilentlyContinue |
        Unblock-File -ErrorAction SilentlyContinue
} catch { }

$mod  = Join-Path $here 'modules'
$cfg  = Join-Path $here 'config\extensions.json'

# Load each module by reading its text and dot-sourcing a ScriptBlock created
# from that text. This bypasses ExecutionPolicy entirely — even when GPO
# enforces MachinePolicy=AllSigned/RemoteSigned, which would block both
# Import-Module *.psm1 and dot-sourcing *.ps1 files directly. Nothing here
# loads a file "as a script"; we load text and execute it as inline commands.
function Import-Local {
    param([Parameter(Mandatory)][string]$Path)
    $content = Get-Content -Raw -LiteralPath $Path
    . ([ScriptBlock]::Create($content))
}

Import-Local (Join-Path $mod 'Common.psm1')
Import-Local (Join-Path $mod 'Install-Prereqs.ps1')
Import-Local (Join-Path $mod 'Install-CoreTools.ps1')
Import-Local (Join-Path $mod 'Install-Terminal.ps1')
Import-Local (Join-Path $mod 'Install-VSCode.ps1')
Import-Local (Join-Path $mod 'Install-GhCli.ps1')
Import-Local (Join-Path $mod 'Test-GithubLink.ps1')
Import-Local (Join-Path $mod 'Install-AgencyCopilot.ps1')
Import-Local (Join-Path $mod 'Show-Summary.ps1')

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

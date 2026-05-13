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

    Runs in two modes automatically:
      - LOCAL  : when invoked from a file on disk ($PSCommandPath set).
      - REMOTE : when piped via `iex (irm ...)`. Modules are fetched from
                 raw.githubusercontent.com on the fly. Same UX as Agency's
                 `iex "& { $(irm aka.ms/InstallTool.ps1) } agency"`.

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
    # Seamless one-liner (no clone, no download, GPO-immune):
    iex "& { $(irm https://raw.githubusercontent.com/vamckMS/pm-hackathon-bootscript/main/bootstrap.ps1) }"

.EXAMPLE
    # From a local clone / zip:
    .\bootstrap.cmd            # CMD / double-click
    .\bootstrap.ps1            # PowerShell (if ExecutionPolicy allows)

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

# ---------- Source-of-truth URLs (used in remote mode and self-elevation) ----------
$script:BootstrapUrl = 'https://raw.githubusercontent.com/vamckMS/pm-hackathon-bootscript/main/bootstrap.ps1'
$script:BaseUrl      = 'https://raw.githubusercontent.com/vamckMS/pm-hackathon-bootscript/main'

# ---------- Mode detection ----------
# Remote mode = invoked via `iex (irm ...)` — no script file on disk.
$script:Here     = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $null }
$script:IsRemote = -not $script:Here

# TLS 1.2 for older Windows PowerShell 5.1 hosts
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

# ---------- Self-elevate ----------
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "Re-launching elevated..." -ForegroundColor Yellow

    function _q([string]$s) { "'" + ($s -replace "'", "''") + "'" }
    $params = @()
    if ($WhatIf)             { $params += '-WhatIf' }
    if ($Force)              { $params += '-Force ' + (($Force | ForEach-Object { _q $_ }) -join ',') }
    if ($GithubUsername)     { $params += '-GithubUsername ' + (_q $GithubUsername) }
    if ($SkipGhValidation)   { $params += '-SkipGhValidation' }
    if ($AgencyTag)          { $params += '-AgencyTag ' + (_q $AgencyTag) }
    $paramStr = ($params -join ' ')

    if ($script:IsRemote) {
        # Remote mode: elevated process re-fetches and pipes via iex. Nothing on disk.
        $cmd = "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex `"& { `$(irm '$script:BootstrapUrl') } $paramStr`""
    } else {
        # Local mode: elevated process loads the file as text and runs it via ScriptBlock,
        # so GPO-enforced ExecutionPolicy (MachinePolicy/UserPolicy) cannot block it.
        $cmd = "& ([ScriptBlock]::Create((Get-Content -Raw -LiteralPath " + (_q $PSCommandPath) + "))) $paramStr"
    }

    $bytes   = [System.Text.Encoding]::Unicode.GetBytes($cmd)
    $encoded = [Convert]::ToBase64String($bytes)

    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded)
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    return
}

$ErrorActionPreference = 'Stop'
Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue | Out-Null

# ---------- Module loader (dual mode) ----------
# Loads scripts as TEXT and dot-sources via [ScriptBlock]::Create.
# Local mode reads from disk; remote mode fetches from raw.githubusercontent.com.
# Either way, no script FILE is executed — so GPO ExecutionPolicy cannot block it.
function Import-Local {
    param([Parameter(Mandatory)][string]$RelPath)
    if ($script:IsRemote) {
        $url = ($script:BaseUrl + '/' + $RelPath).Replace('\','/')
        Write-Host "[load] $url" -ForegroundColor DarkGray
        $content = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
    } else {
        $full = Join-Path $script:Here $RelPath
        $content = Get-Content -Raw -LiteralPath $full
    }
    . ([ScriptBlock]::Create($content))
}

# Clear MOTW on local files so any subsequent file-based ops are safe.
if (-not $script:IsRemote) {
    try {
        Get-ChildItem -Path $script:Here -Recurse -File -ErrorAction SilentlyContinue |
            Unblock-File -ErrorAction SilentlyContinue
    } catch { }
}

Import-Local 'modules/Common.psm1'
Import-Local 'modules/Install-Prereqs.ps1'
Import-Local 'modules/Install-CoreTools.ps1'
Import-Local 'modules/Install-Terminal.ps1'
Import-Local 'modules/Install-VSCode.ps1'
Import-Local 'modules/Install-GhCli.ps1'
Import-Local 'modules/Test-GithubLink.ps1'
Import-Local 'modules/Install-AgencyCopilot.ps1'
Import-Local 'modules/Show-Summary.ps1'

# Resolve the extensions config path (Install-VSCode wants a file path).
if ($script:IsRemote) {
    $cfg = Join-Path $env:TEMP 'pm-hackathon-extensions.json'
    Write-Host "[load] $script:BaseUrl/config/extensions.json -> $cfg" -ForegroundColor DarkGray
    (Invoke-WebRequest -Uri "$script:BaseUrl/config/extensions.json" -UseBasicParsing).Content |
        Out-File -FilePath $cfg -Encoding UTF8
} else {
    $cfg = Join-Path $script:Here 'config\extensions.json'
}

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

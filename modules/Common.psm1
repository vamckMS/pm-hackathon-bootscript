# Common.psm1 — shared helpers for the PM Hackathon bootstrap.
# Requires PowerShell 5.1+. Self-contained: no external module dependencies.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------- Module-scoped state ----------

$script:LogPath        = $null
$script:StateRoot      = Join-Path $env:LOCALAPPDATA 'PMHackathonBootstrap'
$script:StateDir       = Join-Path $script:StateRoot 'state'
$script:LogDir         = Join-Path $script:StateRoot 'logs'
$script:Results        = New-Object System.Collections.Generic.List[object]
$script:WhatIfMode     = $false
$script:ForceModules   = @()

# Module result statuses
$script:VALID_STATUSES = @('Installed','AlreadyPresent','Upgraded','Skipped','Failed','Verified')

# ---------- Initialization ----------

function Initialize-Bootstrap {
    [CmdletBinding()]
    param(
        [switch]$WhatIfMode,
        [string[]]$Force
    )

    $null = New-Item -ItemType Directory -Force -Path $script:StateDir, $script:LogDir
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:LogPath = Join-Path $script:LogDir "bootstrap-$stamp.log"
    $script:WhatIfMode   = [bool]$WhatIfMode
    $script:ForceModules = @($Force)

    # Start a transcript for the full session (captures native output too).
    try { Start-Transcript -Path $script:LogPath -Append | Out-Null } catch { }

    Write-Log "Bootstrap initialized. Log: $script:LogPath"
    if ($script:WhatIfMode)   { Write-Log "Running in -WhatIf mode (detect-only)." 'WARN' }
    if ($script:ForceModules) { Write-Log "Force modules: $($script:ForceModules -join ', ')" 'WARN' }
}

function Stop-Bootstrap {
    try { Stop-Transcript | Out-Null } catch { }
}

# ---------- Logging ----------

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)] [string]$Message,
        [Parameter(Position=1)] [ValidateSet('INFO','WARN','ERROR','OK','STEP')] [string]$Level = 'INFO'
    )
    $ts   = Get-Date -Format 'HH:mm:ss'
    $line = "[$ts][$Level] $Message"
    switch ($Level) {
        'OK'    { Write-Host $line -ForegroundColor Green }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'STEP'  { Write-Host ""; Write-Host $line -ForegroundColor Cyan }
        default { Write-Host $line }
    }
}

function Write-Step {
    param([string]$Name)
    Write-Log "=== $Name ===" 'STEP'
}

# ---------- Mode helpers ----------

function Test-WhatIfMode { return [bool]$script:WhatIfMode }

function Test-ForceModule {
    param([Parameter(Mandatory)][string]$ModuleId)
    return ($script:ForceModules -contains $ModuleId) -or ($script:ForceModules -contains 'all')
}

# ---------- Admin / elevation ----------

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Assert-Admin {
    if (-not (Test-Admin)) {
        throw "Administrator privileges required. The bootstrap should self-elevate; if you see this, re-run from an elevated PowerShell."
    }
}

# ---------- Command detection ----------

function Test-Command {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-CommandVersion {
    param(
        [Parameter(Mandatory)][string]$Command,
        [string[]]$Args = @('--version')
    )
    try {
        $out = & $Command @Args 2>&1 | Out-String
        return $out.Trim()
    } catch {
        return $null
    }
}

# ---------- Connectivity ----------

function Test-Internet {
    param([string[]]$Hosts = @('github.com','aka.ms'))
    foreach ($h in $Hosts) {
        try {
            $r = Test-Connection -ComputerName $h -Count 1 -Quiet -ErrorAction Stop
            if ($r) { return $true }
        } catch { }
    }
    return $false
}

# ---------- Result tracking ----------

function Add-Result {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Module,
        [Parameter(Mandatory)][ValidateSet('Installed','AlreadyPresent','Upgraded','Skipped','Failed','Verified')]
            [string]$Status,
        [string]$Detail = ''
    )
    $script:Results.Add([pscustomobject]@{
        Module = $Module
        Status = $Status
        Detail = $Detail
        Time   = (Get-Date -Format 'HH:mm:ss')
    })

    $levelMap = @{
        Installed = 'OK'; AlreadyPresent = 'OK'; Upgraded = 'OK'; Verified = 'OK';
        Skipped = 'WARN'; Failed = 'ERROR'
    }
    Write-Log "[$Module] $Status — $Detail" $levelMap[$Status]
}

function Get-Results { return $script:Results.ToArray() }

# ---------- winget / choco wrappers ----------

function Test-Winget { return (Test-Command 'winget') }
function Test-Choco  { return (Test-Command 'choco')  }

function Test-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)
    if (-not (Test-Winget)) { return $false }
    try {
        $out = winget list --id $Id --exact --accept-source-agreements 2>&1 | Out-String
        # winget exits 0 even when not found; rely on string presence.
        return ($out -match [regex]::Escape($Id))
    } catch { return $false }
}

function Install-WithWinget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$DisplayName = $Id
    )
    if (-not (Test-Winget)) { return @{ Ok=$false; Reason='winget not available' } }
    Write-Log "winget install $Id ($DisplayName)..."
    try {
        $args = @('install','--id', $Id, '--exact',
                  '--silent',
                  '--accept-package-agreements','--accept-source-agreements',
                  '--source','winget')
        $p = Start-Process -FilePath 'winget' -ArgumentList $args -Wait -PassThru -NoNewWindow
        # winget success exit codes: 0, and some "already installed" variants
        if ($p.ExitCode -eq 0) { return @{ Ok=$true; Code=$p.ExitCode } }
        if ($p.ExitCode -eq -1978335189) { return @{ Ok=$true; Code=$p.ExitCode; Note='already installed (winget)' } }
        return @{ Ok=$false; Code=$p.ExitCode; Reason="winget exit $($p.ExitCode)" }
    } catch {
        return @{ Ok=$false; Reason=$_.Exception.Message }
    }
}

function Install-WithChoco {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$DisplayName = $Id
    )
    if (-not (Test-Choco)) { return @{ Ok=$false; Reason='choco not available' } }
    Write-Log "choco install $Id ($DisplayName)..."
    try {
        $p = Start-Process -FilePath 'choco' -ArgumentList @('install',$Id,'-y','--no-progress','--limit-output') -Wait -PassThru -NoNewWindow
        if ($p.ExitCode -in @(0,1605,3010)) { return @{ Ok=$true; Code=$p.ExitCode } }
        return @{ Ok=$false; Code=$p.ExitCode; Reason="choco exit $($p.ExitCode)" }
    } catch {
        return @{ Ok=$false; Reason=$_.Exception.Message }
    }
}

# Install a package: prefer winget, fall back to choco. Skip if already present.
function Install-Package {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModuleId,
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][string]$WingetId,
        [string]$ChocoId,
        [scriptblock]$DetectScript  # returns $true if already installed
    )

    # Idempotency gate.
    $forced = Test-ForceModule -ModuleId $ModuleId
    if (-not $forced -and $DetectScript) {
        try {
            if (& $DetectScript) {
                Add-Result -Module $ModuleId -Status 'AlreadyPresent' -Detail $DisplayName
                return
            }
        } catch {
            Write-Log "Detection for $DisplayName errored: $($_.Exception.Message). Proceeding to install." 'WARN'
        }
    }

    if (Test-WhatIfMode) {
        Add-Result -Module $ModuleId -Status 'Skipped' -Detail "WhatIf: would install $DisplayName"
        return
    }

    $r = Install-WithWinget -Id $WingetId -DisplayName $DisplayName
    if ($r.Ok) {
        Add-Result -Module $ModuleId -Status 'Installed' -Detail "$DisplayName via winget"
        return
    }
    Write-Log "winget failed for $DisplayName ($($r.Reason)). Trying Chocolatey..." 'WARN'

    if ($ChocoId) {
        $r2 = Install-WithChoco -Id $ChocoId -DisplayName $DisplayName
        if ($r2.Ok) {
            Add-Result -Module $ModuleId -Status 'Installed' -Detail "$DisplayName via choco"
            return
        }
        Add-Result -Module $ModuleId -Status 'Failed' -Detail "winget: $($r.Reason); choco: $($r2.Reason)"
        return
    }
    Add-Result -Module $ModuleId -Status 'Failed' -Detail $r.Reason
}

# ---------- State markers (for steps without reliable vendor detection) ----------

function Set-StateMarker {
    param([Parameter(Mandatory)][string]$Name, [string]$Value = (Get-Date -Format o))
    $f = Join-Path $script:StateDir "$Name.marker"
    Set-Content -Path $f -Value $Value -Encoding UTF8
    return $f
}

function Test-StateMarker {
    param([Parameter(Mandatory)][string]$Name)
    return (Test-Path (Join-Path $script:StateDir "$Name.marker"))
}

# ---------- Safe JSON config edits ----------

function Backup-File {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bak    = "$Path.bak.$stamp"
    Copy-Item -Path $Path -Destination $bak -Force
    Write-Log "Backed up $Path -> $bak"
    return $bak
}

# ---------- Paths ----------

function Get-LogPath   { return $script:LogPath }
function Get-StateDir  { return $script:StateDir }
function Get-StateRoot { return $script:StateRoot }

Export-ModuleMember -Function `
    Initialize-Bootstrap, Stop-Bootstrap, `
    Write-Log, Write-Step, `
    Test-WhatIfMode, Test-ForceModule, `
    Test-Admin, Assert-Admin, `
    Test-Command, Get-CommandVersion, `
    Test-Internet, `
    Add-Result, Get-Results, `
    Test-Winget, Test-Choco, Test-WingetPackage, `
    Install-WithWinget, Install-WithChoco, Install-Package, `
    Set-StateMarker, Test-StateMarker, `
    Backup-File, `
    Get-LogPath, Get-StateDir, Get-StateRoot

# Install-Prereqs.ps1 — ensures winget (App Installer) and optionally Chocolatey.

function Invoke-PrereqsStep {
    Write-Step 'Preflight + package managers'

    # OS / PS version sanity
    $os = [System.Environment]::OSVersion.Version
    if ($os.Major -lt 10) {
        Add-Result -Module 'preflight' -Status 'Failed' -Detail "Windows 10/11 required (found $os)"
        throw "Unsupported OS."
    }
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Add-Result -Module 'preflight' -Status 'Failed' -Detail "PowerShell 5.1+ required"
        throw "Unsupported PowerShell."
    }
    Add-Result -Module 'preflight' -Status 'Verified' -Detail "Win $os, PS $($PSVersionTable.PSVersion)"

    # Connectivity
    if (Test-Internet) {
        Add-Result -Module 'connectivity' -Status 'Verified' -Detail 'github.com / aka.ms reachable'
    } else {
        Add-Result -Module 'connectivity' -Status 'Failed' -Detail 'No internet reachable'
        throw "Network unreachable."
    }

    # winget
    if (Test-Winget) {
        Add-Result -Module 'winget' -Status 'AlreadyPresent' -Detail (Get-CommandVersion 'winget')
    } else {
        if (Test-WhatIfMode) {
            Add-Result -Module 'winget' -Status 'Skipped' -Detail 'WhatIf: would install App Installer'
        } else {
            Write-Log "winget not found. Attempting to install App Installer from Microsoft Store..."
            try {
                # ms-windows-store opens the Store page; user may need to click Install.
                # Best-effort programmatic install via Add-AppxPackage requires bundle file.
                Start-Process 'ms-windows-store://pdp/?productid=9NBLGGH4NNS1' | Out-Null
                Add-Result -Module 'winget' -Status 'Skipped' -Detail 'Opened Store page — install App Installer, then re-run bootstrap.'
                throw "winget required; please install App Installer and re-run."
            } catch {
                Add-Result -Module 'winget' -Status 'Failed' -Detail $_.Exception.Message
                throw
            }
        }
    }

    # Chocolatey is installed lazily — only if a later step needs it as fallback.
    if (Test-Choco) {
        Add-Result -Module 'choco' -Status 'AlreadyPresent' -Detail (Get-CommandVersion 'choco')
    } else {
        Add-Result -Module 'choco' -Status 'Skipped' -Detail 'Not installed (lazy — will install only if a winget step falls back)'
    }
}

function Install-ChocoLazy {
    # Called by Install-Package indirectly: today we install upfront if user has -InstallChoco,
    # or we attempt now. Simplest: install only when explicitly requested via this function.
    if (Test-Choco) { return $true }
    if (Test-WhatIfMode) {
        Write-Log "WhatIf: would install Chocolatey." 'WARN'
        return $false
    }
    Write-Log "Installing Chocolatey..."
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = `
            [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        $script = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
        Invoke-Expression $script
        # Refresh PATH for current session
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                    [System.Environment]::GetEnvironmentVariable('Path','User')
        return (Test-Choco)
    } catch {
        Write-Log "Chocolatey install failed: $($_.Exception.Message)" 'ERROR'
        return $false
    }
}

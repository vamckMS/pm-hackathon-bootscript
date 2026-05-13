# Install-Terminal.ps1 — Windows Terminal + PowerShell 7 + add PS7 profile to WT.

function Invoke-TerminalStep {
    Write-Step 'Terminal stack (Windows Terminal + PowerShell 7)'

    Install-Package -ModuleId 'windows-terminal' -DisplayName 'Windows Terminal' `
        -WingetId 'Microsoft.WindowsTerminal' -ChocoId 'microsoft-windows-terminal' `
        -DetectScript {
            [bool](Get-AppxPackage -Name 'Microsoft.WindowsTerminal' -ErrorAction SilentlyContinue) `
                -or (Test-Command 'wt')
        }

    Install-Package -ModuleId 'powershell-7' -DisplayName 'PowerShell 7' `
        -WingetId 'Microsoft.PowerShell' -ChocoId 'powershell-core' `
        -DetectScript {
            if (-not (Test-Command 'pwsh')) { return $false }
            try {
                $v = (& pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()').Trim()
                return ([Version]$v).Major -ge 7
            } catch { return $true }
        }

    Add-Ps7ProfileToWindowsTerminal
}

function Add-Ps7ProfileToWindowsTerminal {
    $moduleId = 'wt-ps7-profile'

    if (Test-WhatIfMode) {
        Add-Result -Module $moduleId -Status 'Skipped' -Detail 'WhatIf: would patch WT settings.json'
        return
    }

    $pkg = Get-AppxPackage -Name 'Microsoft.WindowsTerminal' -ErrorAction SilentlyContinue
    if (-not $pkg) {
        Add-Result -Module $moduleId -Status 'Skipped' -Detail 'Windows Terminal not installed (Appx not found)'
        return
    }

    $settingsPath = Join-Path $env:LOCALAPPDATA `
        ('Packages\{0}_{1}\LocalState\settings.json' -f $pkg.Name, $pkg.PublisherId)
    if (-not (Test-Path $settingsPath)) {
        Add-Result -Module $moduleId -Status 'Skipped' -Detail "WT settings.json not found at $settingsPath (launch WT once to create it)"
        return
    }

    $pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwshPath) {
        Add-Result -Module $moduleId -Status 'Failed' -Detail 'pwsh.exe not found on PATH'
        return
    }

    try {
        $raw = Get-Content -Raw -Path $settingsPath
        $json = $raw | ConvertFrom-Json

        if (-not $json.profiles) {
            $json | Add-Member -NotePropertyName 'profiles' -NotePropertyValue ([pscustomobject]@{ list = @() }) -Force
        }
        if (-not $json.profiles.list) {
            $json.profiles | Add-Member -NotePropertyName 'list' -NotePropertyValue @() -Force
        }

        # Detection: any existing profile that targets pwsh?
        $existing = $json.profiles.list | Where-Object {
            ($_.source -eq 'Windows.Terminal.PowershellCore') -or
            ($_.commandline -and ($_.commandline -match 'pwsh(\.exe)?\s*$' -or $_.commandline -match 'pwsh(\.exe)?\s+'))
        }

        if ($existing -and -not (Test-ForceModule -ModuleId $moduleId)) {
            Add-Result -Module $moduleId -Status 'AlreadyPresent' -Detail "Profile present: $($existing[0].name)"
            return
        }

        # Backup before edit
        $bak = Backup-File -Path $settingsPath

        $newProfile = [pscustomobject]@{
            name        = 'PowerShell 7'
            commandline = $pwshPath
            guid        = ('{' + [Guid]::NewGuid().ToString() + '}')
            hidden      = $false
            icon        = 'ms-appx:///ProfileIcons/{61c54bbd-c2c6-5271-96e7-009a87ff44bf}.png'
        }

        $json.profiles.list = @($json.profiles.list) + $newProfile
        $out = $json | ConvertTo-Json -Depth 32
        Set-Content -Path $settingsPath -Value $out -Encoding UTF8

        Add-Result -Module $moduleId -Status 'Installed' -Detail "Added PS7 profile; backup at $bak"
    } catch {
        Add-Result -Module $moduleId -Status 'Failed' -Detail $_.Exception.Message
    }
}

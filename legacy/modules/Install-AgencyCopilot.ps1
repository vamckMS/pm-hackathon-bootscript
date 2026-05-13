# Install-AgencyCopilot.ps1 — install Agency Copilot via the official aka.ms one-liner.
# Fallback: download the LATEST release from the GitHub repo and run the installer.

function Invoke-AgencyCopilotStep {
    param(
        [string]$FallbackRepo = 'ahsi-microsoft/agency-cowork',
        # Optional override; if empty/null the script resolves the latest tag at runtime.
        [string]$FallbackTag  = ''
    )

    Write-Step 'Agency Copilot (PM Mosaic on Agency)'

    $moduleId = 'agency-copilot'
    $marker   = 'agency.installed'

    if ((Test-StateMarker -Name $marker) -and -not (Test-ForceModule -ModuleId $moduleId)) {
        Add-Result -Module $moduleId -Status 'AlreadyPresent' -Detail 'Install marker present from previous run'
        return
    }

    if (Test-WhatIfMode) {
        Add-Result -Module $moduleId -Status 'Skipped' -Detail 'WhatIf: would run aka.ms/InstallTool.ps1 agency (fallback: latest release of agency-cowork)'
        return
    }

    # Primary: official wiki one-liner.
    $primaryOk = $false
    try {
        Write-Log "Invoking: iex `"& { `$(irm aka.ms/InstallTool.ps1) } agency`""
        $script = Invoke-RestMethod -Uri 'https://aka.ms/InstallTool.ps1' -UseBasicParsing
        $sb = [scriptblock]::Create($script)
        & $sb agency
        $primaryOk = $true
    } catch {
        Write-Log "Primary Agency install failed: $($_.Exception.Message)" 'WARN'
    }

    if ($primaryOk) {
        Set-StateMarker -Name $marker -Value "primary;$(Get-Date -Format o)" | Out-Null
        Add-Result -Module $moduleId -Status 'Installed' -Detail 'Installed via aka.ms/InstallTool.ps1 (primary)'
        return
    }

    # Fallback: pull the LATEST release from the repo.
    if (-not (Test-Command 'gh')) {
        Add-Result -Module $moduleId -Status 'Failed' -Detail "Primary failed and 'gh' not on PATH for fallback"
        return
    }

    # Resolve the tag to download. If caller didn't pin one, ask GitHub for the latest.
    $tag = $FallbackTag
    if ([string]::IsNullOrWhiteSpace($tag)) {
        try {
            Write-Log "Resolving latest release tag from $FallbackRepo..."
            $tag = (& gh release view --repo $FallbackRepo --json tagName --jq .tagName 2>$null).Trim()
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tag)) { $tag = '' }
        } catch { $tag = '' }
    }

    $dlDir = Join-Path (Get-StateDir) ("agency-release-" + ($(if ($tag) { $tag } else { 'latest' })))
    $null  = New-Item -ItemType Directory -Force -Path $dlDir

    try {
        if ($tag) {
            Write-Log "gh release download $tag --repo $FallbackRepo --dir $dlDir"
            & gh release download $tag --repo $FallbackRepo --dir $dlDir --skip-existing
        } else {
            # No tag resolved — let gh pick the latest implicitly.
            Write-Log "gh release download (latest) --repo $FallbackRepo --dir $dlDir"
            & gh release download --repo $FallbackRepo --dir $dlDir --skip-existing
        }
        if ($LASTEXITCODE -ne 0) {
            Add-Result -Module $moduleId -Status 'Failed' `
                -Detail "Both paths failed. gh release download exit $LASTEXITCODE. Wiki: https://aka.ms/agency-quickstart"
            return
        }
    } catch {
        Add-Result -Module $moduleId -Status 'Failed' -Detail "Fallback download error: $($_.Exception.Message)"
        return
    }

    # Locate installer asset (msi/exe). The exact asset name is intentionally not pinned —
    # whatever the latest release ships is what we run.
    $installer = Get-ChildItem -Path $dlDir -Include *.msi,*.exe -Recurse | Select-Object -First 1
    if (-not $installer) {
        Add-Result -Module $moduleId -Status 'Failed' `
            -Detail "Downloaded release but found no .msi/.exe in $dlDir. Open the folder and run the installer manually."
        return
    }
    try {
        if ($installer.Extension -ieq '.msi') {
            $p = Start-Process 'msiexec.exe' -ArgumentList @('/i', "`"$($installer.FullName)`"", '/qn','/norestart') -Wait -PassThru
        } else {
            $p = Start-Process $installer.FullName -ArgumentList '/S' -Wait -PassThru
        }
        if ($p.ExitCode -in @(0,3010)) {
            $resolvedTag = if ($tag) { $tag } else { 'latest' }
            Set-StateMarker -Name $marker -Value "fallback;$resolvedTag;$($installer.Name);$(Get-Date -Format o)" | Out-Null
            Add-Result -Module $moduleId -Status 'Installed' -Detail "Installed via fallback ($resolvedTag): $($installer.Name)"
        } else {
            Add-Result -Module $moduleId -Status 'Failed' -Detail "Installer exit $($p.ExitCode)"
        }
    } catch {
        Add-Result -Module $moduleId -Status 'Failed' -Detail $_.Exception.Message
    }
}

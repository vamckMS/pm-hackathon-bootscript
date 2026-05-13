# Install-GhCli.ps1 — install the github/gh-copilot extension on top of gh CLI.

function Invoke-GhCopilotExtensionStep {
    Write-Step 'GitHub Copilot CLI (gh extension)'

    if (-not (Test-Command 'gh')) {
        Add-Result -Module 'gh-copilot-extension' -Status 'Failed' -Detail "'gh' CLI not on PATH. Re-run bootstrap after restarting the shell."
        return
    }

    $forced = Test-ForceModule -ModuleId 'gh-copilot-extension'
    $alreadyInstalled = $false
    try {
        $list = (& gh extension list 2>$null) -join "`n"
        $alreadyInstalled = ($list -match 'github/gh-copilot') -or ($list -match 'gh-copilot')
    } catch { }

    if ($alreadyInstalled -and -not $forced) {
        Add-Result -Module 'gh-copilot-extension' -Status 'AlreadyPresent' -Detail 'github/gh-copilot'
    } else {
        if (Test-WhatIfMode) {
            Add-Result -Module 'gh-copilot-extension' -Status 'Skipped' -Detail 'WhatIf: would install github/gh-copilot'
            return
        }
        try {
            $p = Start-Process -FilePath 'gh' -ArgumentList @('extension','install','github/gh-copilot','--force') -Wait -PassThru -NoNewWindow
            if ($p.ExitCode -eq 0) {
                Add-Result -Module 'gh-copilot-extension' -Status 'Installed' -Detail 'github/gh-copilot'
            } else {
                Add-Result -Module 'gh-copilot-extension' -Status 'Failed' -Detail "gh extension install exit $($p.ExitCode)"
                return
            }
        } catch {
            Add-Result -Module 'gh-copilot-extension' -Status 'Failed' -Detail $_.Exception.Message
            return
        }
    }

    # Verify
    try {
        $v = (& gh copilot --version 2>$null) -join ' '
        if ($LASTEXITCODE -eq 0 -and $v) {
            Add-Result -Module 'gh-copilot-verify' -Status 'Verified' -Detail $v.Trim()
        }
    } catch { }
}

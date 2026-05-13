# Install-VSCode.ps1 — VS Code + extensions from config/extensions.json.

function Invoke-VSCodeStep {
    param([Parameter(Mandatory)][string]$ExtensionsConfigPath)

    Write-Step 'VS Code + extensions'

    Install-Package -ModuleId 'vscode' -DisplayName 'Visual Studio Code' `
        -WingetId 'Microsoft.VisualStudioCode' -ChocoId 'vscode' `
        -DetectScript { Test-Command 'code' }

    if (-not (Test-Command 'code')) {
        # PATH may not be refreshed yet in this session
        $candidate = Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'
        if (Test-Path $candidate) { $env:Path = "$env:Path;$(Split-Path $candidate)" }
        $candidate2 = "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
        if (Test-Path $candidate2) { $env:Path = "$env:Path;$(Split-Path $candidate2)" }
    }

    if (-not (Test-Command 'code')) {
        Add-Result -Module 'vscode-extensions' -Status 'Failed' -Detail "'code' not on PATH; cannot install extensions in this session. Re-run bootstrap after restarting the shell."
        return
    }

    if (-not (Test-Path $ExtensionsConfigPath)) {
        Add-Result -Module 'vscode-extensions' -Status 'Failed' -Detail "extensions.json not found at $ExtensionsConfigPath"
        return
    }

    $cfg = Get-Content -Raw -Path $ExtensionsConfigPath | ConvertFrom-Json

    # Support both new schema (coreExtensions + mcpExtensions) and legacy 'extensions'.
    $list = @()
    if ($cfg.PSObject.Properties.Name -contains 'coreExtensions') { $list += @($cfg.coreExtensions) }
    if ($cfg.PSObject.Properties.Name -contains 'mcpExtensions')  { $list += @($cfg.mcpExtensions) }
    if (-not $list -and $cfg.PSObject.Properties.Name -contains 'extensions') { $list = @($cfg.extensions) }
    $list = $list | Where-Object { $_ -and $_.id -and (($null -eq $_.enabled) -or $_.enabled) }

    if (-not $list -or $list.Count -eq 0) {
        Add-Result -Module 'vscode-extensions' -Status 'Skipped' -Detail 'No extensions defined in config (MCP list is a placeholder until organizers finalize it).'
        return
    }

    $installed = @()
    try { $installed = (& code --list-extensions) 2>$null } catch { }
    $installedLower = $installed | ForEach-Object { $_.ToLowerInvariant() }

    foreach ($ext in $list) {
        $id   = $ext.id
        $name = if ($ext.name) { $ext.name } else { $ext.id }
        $mid  = "vsx:$id"

        if (-not (Test-ForceModule -ModuleId 'vscode-extensions') -and ($installedLower -contains $id.ToLowerInvariant())) {
            Add-Result -Module $mid -Status 'AlreadyPresent' -Detail $name
            continue
        }
        if (Test-WhatIfMode) {
            Add-Result -Module $mid -Status 'Skipped' -Detail "WhatIf: would install $name"
            continue
        }
        try {
            $p = Start-Process -FilePath 'code' -ArgumentList @('--install-extension',$id,'--force') -Wait -PassThru -NoNewWindow
            if ($p.ExitCode -eq 0) {
                Add-Result -Module $mid -Status 'Installed' -Detail $name
            } else {
                Add-Result -Module $mid -Status 'Failed' -Detail "code exit $($p.ExitCode)"
            }
        } catch {
            Add-Result -Module $mid -Status 'Failed' -Detail $_.Exception.Message
        }
    }
}

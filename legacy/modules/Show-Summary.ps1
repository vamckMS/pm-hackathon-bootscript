# Show-Summary.ps1 — render the final per-step status table + next steps.

function Show-Summary {
    Write-Step 'Summary'

    $results = Get-Results
    if (-not $results -or $results.Count -eq 0) {
        Write-Log "No results recorded." 'WARN'
        return 1
    }

    $statusIcon = @{
        Installed      = '✅'
        AlreadyPresent = '✅'
        Upgraded       = '✅'
        Verified       = '✅'
        Skipped        = '⚠️'
        Failed         = '❌'
    }

    $table = $results | ForEach-Object {
        [pscustomobject]@{
            ' ' = $statusIcon[$_.Status]
            'Module' = $_.Module
            'Status' = $_.Status
            'Detail' = if ($_.Detail.Length -gt 70) { $_.Detail.Substring(0,67) + '...' } else { $_.Detail }
        }
    }
    $table | Format-Table -AutoSize | Out-Host

    $failed  = @($results | Where-Object Status -eq 'Failed')
    $skipped = @($results | Where-Object Status -eq 'Skipped')

    Write-Host ""
    Write-Host "Log file: $(Get-LogPath)" -ForegroundColor Cyan
    Write-Host "State dir: $(Get-StateDir)" -ForegroundColor Cyan
    Write-Host ""

    if ($failed.Count -gt 0) {
        Write-Log "$($failed.Count) step(s) FAILED. Review the table above and the log file." 'ERROR'
    } elseif ($skipped.Count -gt 0) {
        Write-Log "Completed with $($skipped.Count) skipped step(s) — review and re-run if needed." 'WARN'
    } else {
        Write-Log "All steps green. You're ready for the hackathon!" 'OK'
    }

    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  - Launch Windows Terminal and switch to the 'PowerShell 7' profile"
    Write-Host "  - Open VS Code; sign into GitHub Copilot when prompted"
    Write-Host "  - Try: gh copilot suggest 'list files modified today'"
    Write-Host "  - Launch Agency Copilot from Start menu (or rerun the wiki one-liner)"
    Write-Host "  - Hackathon Quick Start: https://azurecsi.visualstudio.com/CHIE%20Wiki/_wiki/wikis/CHIE-Wiki.wiki/72793/Getting-Started"
    Write-Host ""

    if ($failed.Count -gt 0) { return 1 } else { return 0 }
}

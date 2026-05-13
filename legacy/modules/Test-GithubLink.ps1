# Test-GithubLink.ps1 — prompt for GH username, ensure auth, validate Microsoft-link.

function Invoke-GhAuthValidateStep {
    param(
        [string]$ExpectedUsername,   # if supplied, skip prompt
        [switch]$SkipValidation
    )

    Write-Step 'GitHub auth + Microsoft-link validation'

    if ($SkipValidation) {
        Add-Result -Module 'gh-validation' -Status 'Skipped' -Detail '-SkipGhValidation requested'
        return $true
    }
    if (-not (Test-Command 'gh')) {
        Add-Result -Module 'gh-validation' -Status 'Failed' -Detail "'gh' CLI not on PATH"
        return $false
    }

    # 1) Prompt for username
    if (-not $ExpectedUsername) {
        $ExpectedUsername = Read-Host "Enter your GitHub username (the Microsoft-linked one)"
    }
    $ExpectedUsername = $ExpectedUsername.Trim()
    if (-not $ExpectedUsername) {
        Add-Result -Module 'gh-validation' -Status 'Failed' -Detail 'No username provided'
        return $false
    }

    # 2) Ensure authenticated
    $authed = $false
    try {
        & gh auth status *> $null
        $authed = ($LASTEXITCODE -eq 0)
    } catch { $authed = $false }

    if (-not $authed) {
        if (Test-WhatIfMode) {
            Add-Result -Module 'gh-auth' -Status 'Skipped' -Detail 'WhatIf: would run gh auth login'
            return $false
        }
        Write-Log "Launching 'gh auth login' (web flow). Complete in your browser..."
        try {
            & gh auth login --hostname github.com --git-protocol https --web --scopes 'read:user,read:org'
            if ($LASTEXITCODE -ne 0) {
                Add-Result -Module 'gh-auth' -Status 'Failed' -Detail "gh auth login exit $LASTEXITCODE"
                return $false
            }
        } catch {
            Add-Result -Module 'gh-auth' -Status 'Failed' -Detail $_.Exception.Message
            return $false
        }
    }
    Add-Result -Module 'gh-auth' -Status 'Verified' -Detail 'gh auth status OK'

    # Signal 1: authenticated host
    $statusOut = ''
    try { $statusOut = (& gh auth status --hostname github.com 2>&1 | Out-String) } catch { }
    $signal1 = ($LASTEXITCODE -eq 0) -and ($statusOut -match 'github\.com')

    # Signal 2: username matches
    $actualLogin = $null
    try { $actualLogin = (& gh api user --jq .login 2>$null).Trim() } catch { }
    $signal2 = $actualLogin -and ($actualLogin.ToLowerInvariant() -eq $ExpectedUsername.ToLowerInvariant())

    if (-not $signal2) {
        Add-Result -Module 'gh-username-match' -Status 'Failed' `
            -Detail "Prompted: '$ExpectedUsername' but gh reports: '$actualLogin'"
    } else {
        Add-Result -Module 'gh-username-match' -Status 'Verified' -Detail $actualLogin
    }

    # Signal 3: Copilot entitlement probe
    $planName = $null
    $signal3  = $false

    # 3a: gh copilot status
    try {
        $copStatus = (& gh copilot status 2>&1 | Out-String)
        if ($LASTEXITCODE -eq 0 -and $copStatus) {
            $signal3 = $true
            if ($copStatus -match '(?i)plan[:\s]+(\S+)') { $planName = $matches[1] }
            elseif ($copStatus -match '(?i)(business|enterprise|individual|pro)') { $planName = $matches[1] }
        }
    } catch { }

    # 3b: REST endpoint fallback
    if (-not $signal3) {
        try {
            $bill = (& gh api /user/copilot_billing 2>$null | Out-String)
            if ($LASTEXITCODE -eq 0 -and $bill) {
                $signal3 = $true
                if ($bill -match '"chat_enabled"\s*:\s*true' -or $bill -match '"plan_type"\s*:\s*"([^"]+)"') {
                    if ($matches.Count -gt 1) { $planName = $matches[1] } else { $planName = 'enabled' }
                }
            }
        } catch { }
    }

    if ($signal3) {
        $detail = if ($planName) { "Plan: $planName" } else { 'Copilot entitlement detected' }
        if ($planName -and $planName -match '(?i)individual') {
            Add-Result -Module 'gh-copilot-entitlement' -Status 'Failed' `
                -Detail "$detail — this looks like a personal account. You likely need to re-link via Microsoft EMU SSO."
            $signal3 = $false
        } else {
            Add-Result -Module 'gh-copilot-entitlement' -Status 'Verified' -Detail $detail
        }
    } else {
        Add-Result -Module 'gh-copilot-entitlement' -Status 'Failed' `
            -Detail 'No Copilot entitlement detected. Ensure your GitHub account is linked to your Microsoft identity.'
    }

    $allGreen = $signal1 -and $signal2 -and $signal3
    if (-not $allGreen) {
        Write-Log "" 'WARN'
        Write-Log "GitHub <-> Microsoft link validation FAILED. Remediation:" 'WARN'
        Write-Log "  1) Run: gh auth logout" 'WARN'
        Write-Log "  2) Visit https://github.com/settings/security and ensure your Microsoft EMU identity is linked" 'WARN'
        Write-Log "  3) Re-run bootstrap.ps1" 'WARN'
        Write-Log "  (Or re-run with -SkipGhValidation to bypass — not recommended.)" 'WARN'
    }
    return $allGreen
}

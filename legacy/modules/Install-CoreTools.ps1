# Install-CoreTools.ps1 — Git, Node LTS, Python 3, GitHub CLI.

function Invoke-CoreToolsStep {
    Write-Step 'Core CLI tools'

    Install-Package -ModuleId 'git' -DisplayName 'Git' `
        -WingetId 'Git.Git' -ChocoId 'git' `
        -DetectScript { Test-Command 'git' }

    Install-Package -ModuleId 'node' -DisplayName 'Node.js LTS' `
        -WingetId 'OpenJS.NodeJS.LTS' -ChocoId 'nodejs-lts' `
        -DetectScript {
            if (-not (Test-Command 'node')) { return $false }
            $v = (& node --version) -replace '^v',''
            try { return ([Version]$v).Major -ge 20 } catch { return $true }
        }

    Install-Package -ModuleId 'python' -DisplayName 'Python 3.12' `
        -WingetId 'Python.Python.3.12' -ChocoId 'python' `
        -DetectScript {
            if (Test-Command 'py') {
                try { & py -3 --version *> $null; return ($LASTEXITCODE -eq 0) } catch { }
            }
            return (Test-Command 'python')
        }

    Install-Package -ModuleId 'gh' -DisplayName 'GitHub CLI' `
        -WingetId 'GitHub.cli' -ChocoId 'gh' `
        -DetectScript { Test-Command 'gh' }
}

# PM Hackathon Bootstrap

One-shot Windows setup for PMs joining the Microsoft PM hackathon. Idempotent,
self-elevating, and safe to re-run.

## What it installs

| Category | Tools |
|---|---|
| Package managers | winget (App Installer) + Chocolatey fallback |
| Core CLI | Git, Node.js LTS, Python 3, GitHub CLI |
| Terminal | Windows Terminal, PowerShell 7 (added as a WT profile) |
| Editor | VS Code + extensions (Copilot, Copilot Chat, Copilot CLI, PowerShell, Python, Azure MCP Server, MCP manager) |
| GitHub Copilot CLI | `gh extension install github/gh-copilot` |
| Agency Copilot | Installed via the official `iex "& { $(irm aka.ms/InstallTool.ps1) } agency"`; falls back to `gh release download` of the **latest** release from `ahsi-microsoft/agency-cowork` |

It also prompts for your GitHub username and validates the GitHub ↔ Microsoft link
(so you get unlimited Copilot tokens) using **three independent signals**:

1. `gh auth status --hostname github.com` confirms you're authenticated.
2. `gh api user --jq .login` must match the username you typed.
3. Copilot entitlement probe (`gh copilot status` → `gh api /user/copilot_billing` → GraphQL).

If any signal fails, the script prints a clear remediation block and **skips** the
Agency Copilot install (so you don't waste a re-run cycle later).

## Quick start

Same shape as Agency Copilot's `iex "& { $(irm aka.ms/InstallTool.ps1) } agency"` —
**one line, no clone, no zip, no Git, no `install.cmd`.** The whole bootstrap
(script + 8 modules + config) is fetched in-memory from `raw.githubusercontent.com`
and executed via `iex`, so the launcher is immune to GPO-enforced
`ExecutionPolicy` (no script file is "loaded" in the policy-engine sense).

### From PowerShell (Windows PowerShell 5.1 or PowerShell 7+)

```powershell
iex "& { $(irm https://raw.githubusercontent.com/vamckMS/pm-hackathon-bootscript/main/bootstrap.ps1) }"
```

### From CMD (Win+R → `cmd`)

```cmd
powershell -NoProfile -Command "iex (irm 'https://raw.githubusercontent.com/vamckMS/pm-hackathon-bootscript/main/bootstrap.ps1')"
```

### With arguments

Args go **inside the outer quotes, after the closing `}`** — same shape as
Agency's `iex "& { $(irm aka.ms/InstallTool.ps1) } agency"`.

**From PowerShell:**

```powershell
# Dry run (detect-only, no changes)
iex "& { $(irm https://raw.githubusercontent.com/vamckMS/pm-hackathon-bootscript/main/bootstrap.ps1) } -WhatIf"

# Provide GH username + skip the link check
iex "& { $(irm https://raw.githubusercontent.com/vamckMS/pm-hackathon-bootscript/main/bootstrap.ps1) } -GithubUsername alice-msft -SkipGhValidation"

# Force-reinstall specific modules
iex "& { $(irm https://raw.githubusercontent.com/vamckMS/pm-hackathon-bootscript/main/bootstrap.ps1) } -Force vscode-extensions,agency-copilot"
```

**From CMD** (the inner `$(...)` doesn't work in `cmd`, so capture-then-invoke):

```cmd
:: -WhatIf dry run
powershell -NoProfile -Command "$s = irm 'https://raw.githubusercontent.com/vamckMS/pm-hackathon-bootscript/main/bootstrap.ps1'; & ([ScriptBlock]::Create($s)) -WhatIf"

:: With GH username
powershell -NoProfile -Command "$s = irm 'https://raw.githubusercontent.com/vamckMS/pm-hackathon-bootscript/main/bootstrap.ps1'; & ([ScriptBlock]::Create($s)) -GithubUsername alice-msft"
```

### Already have the repo locally?

Double-click **`bootstrap.cmd`** (or run `.\bootstrap.cmd` from any shell). It
unblocks files and invokes `bootstrap.ps1` via the same GPO-immune ScriptBlock
trick.

### Zero-assumption matrix

| Assumption you might expect | Reality |
|---|---|
| Git installed | ❌ Not required. Nothing is cloned; bootstrap streams itself + modules over HTTPS. Git gets installed *during* the run. |
| You're in PowerShell | ❌ Not required. CMD one-liner above shells out via `powershell -Command`. |
| ExecutionPolicy allows scripts | ❌ Not required. `irm` + `iex` is inline command execution; ExecutionPolicy (including GPO `MachinePolicy`/`UserPolicy`) does not gate it. |
| You unblocked a downloaded zip | ❌ Not required. Nothing is downloaded to disk in the remote path. |
| You're running as Administrator | ❌ Not required. The script self-elevates via UAC and re-fetches itself in the elevated process. |

## Flags

| Flag | Purpose |
|---|---|
| `-WhatIf` | Detect-only dry run — no installs, just shows what would happen. |
| `-Force <module-id>[,...]` | Force-reinstall specific modules (or `'all'`). E.g. `-Force vscode-extensions,agency-copilot`. |
| `-GithubUsername <name>` | Provide your GH username non-interactively. |
| `-SkipGhValidation` | Bypass the GH↔MS link check. Not recommended. |
| `-AgencyTag <tag>` | Pin the Agency fallback to a specific release tag. Default: empty = pull the **latest** release. |

## Idempotency

Every step follows `detect → act only if needed → verify`. Re-running the script on
a fully-set-up machine should produce all green ✅ rows with zero installs. Each
module reports one of: `Installed`, `AlreadyPresent`, `Upgraded`, `Skipped`,
`Failed`, `Verified`.

User config files (currently just Windows Terminal `settings.json`) are **backed up
with a timestamp** before any edit — look for `settings.json.bak.<yyyyMMdd-HHmmss>`.

## Logs & state

- Logs: `%LOCALAPPDATA%\PMHackathonBootstrap\logs\bootstrap-<timestamp>.log`
- State markers: `%LOCALAPPDATA%\PMHackathonBootstrap\state\`

## Customizing the extension list

Edit `config\extensions.json` and re-run.

## Repo layout

```
pm-hackathon-bootscript/
├── bootstrap.ps1                  # Entry point (dual-mode: local OR iex-from-URL)
├── bootstrap.cmd                  # Local CMD launcher (only needed if running offline)
├── README.md
├── config/
│   └── extensions.json            # VS Code extensions list
└── modules/
    ├── Common.psm1                # Logging, winget/choco wrappers, results, state
    ├── Install-Prereqs.ps1        # Preflight + winget/choco
    ├── Install-CoreTools.ps1      # Git, Node, Python, gh
    ├── Install-Terminal.ps1       # WT, PS7, add PS7 profile
    ├── Install-VSCode.ps1         # VS Code + extensions
    ├── Install-GhCli.ps1          # gh-copilot extension
    ├── Test-GithubLink.ps1        # auth + 3-signal validation
    ├── Install-AgencyCopilot.ps1  # aka.ms primary + gh release fallback
    └── Show-Summary.ps1           # Final report
```

## Open items (TBD before tagging v1)

- Lock down the final list of "generic" MCP extensions in `config\extensions.json` → `mcpExtensions` array (currently a placeholder with just the Azure MCP Server).
- Confirm the right Copilot entitlement API endpoint (`/user/copilot_billing` is used today; may need adjustment).

## Troubleshooting

- **"`.ps1` cannot be loaded because running scripts is disabled on this system"** —
  you ran `bootstrap.ps1` directly under a GPO-enforced ExecutionPolicy. Use
  `bootstrap.cmd` instead; it loads the script as text via `[ScriptBlock]::Create`,
  which is not subject to ExecutionPolicy (including GPO `MachinePolicy`/`UserPolicy`).
- **"File is not digitally signed" / "blocked because it came from an internet location"** —
  Mark-of-the-Web from the zip download. `bootstrap.cmd` clears this automatically
  via `Unblock-File`. If running `.ps1` directly, run once:
  `Get-ChildItem -Recurse | Unblock-File`.
- **"`bootstrap.ps1` is not recognized as an internal or external command"** —
  you're in CMD, not PowerShell. Use `bootstrap.cmd` (it works from either shell).
- **`'code' not on PATH`** — restart your shell after VS Code installs, then re-run.
- **`gh` install succeeded but `gh` not found** — same; reopen PowerShell.
- **Agency install fails** — ensure you're on the corp network and authenticated to Microsoft EMU via `gh auth status`.
- **Stuck somewhere** — share the log file from `%LOCALAPPDATA%\PMHackathonBootstrap\logs\`.

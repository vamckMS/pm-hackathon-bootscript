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

From a normal **Windows PowerShell** (5.1) prompt — the script self-elevates:

```powershell
git clone <this-repo-url> pm-hackathon-bootscript
cd pm-hackathon-bootscript
.\bootstrap.ps1
```

Or one-liner (once this is published to a release/raw URL):

```powershell
iwr -UseBasicParsing <raw-url>/bootstrap.ps1 -OutFile $env:TEMP\bootstrap.ps1; & $env:TEMP\bootstrap.ps1
```

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
├── bootstrap.ps1                  # Entry point
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

- **`'code' not on PATH`** — restart your shell after VS Code installs, then re-run.
- **`gh` install succeeded but `gh` not found** — same; reopen PowerShell.
- **Agency install fails** — ensure you're on the corp network and authenticated to Microsoft EMU via `gh auth status`.
- **Stuck somewhere** — share the log file from `%LOCALAPPDATA%\PMHackathonBootstrap\logs\`.

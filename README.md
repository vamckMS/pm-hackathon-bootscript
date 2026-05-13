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

The bootstrap makes **no prerequisite assumptions**:

| Assumption you might expect | Reality |
|---|---|
| You have Git installed | ❌ Not required. The web installer uses `curl` (built into Windows 10/11) to download a zip. Git gets installed *during* the bootstrap. |
| You're in PowerShell | ❌ Not required. The launcher is a `.cmd` and works from CMD, PowerShell, or a double-click. |
| Your ExecutionPolicy allows scripts | ❌ Not required. The launcher passes `-ExecutionPolicy Bypass`. |
| You unblocked the zip you downloaded | ❌ Not required. The launcher runs `Unblock-File` across the tree first. |
| You're running as Administrator | ❌ Not required. The script self-elevates with a UAC prompt. |

### Option A — recommended: one-liner, zero prereqs

Works from **CMD** (Win+R → `cmd`) **or PowerShell**. No Git, no clone, no
download steps. Just paste and press Enter:

```cmd
curl -L -o %TEMP%\pmboot.cmd https://raw.githubusercontent.com/vamckMS/pm-hackathon-bootscript/main/install.cmd && %TEMP%\pmboot.cmd
```

This downloads `install.cmd` with `curl`, which then fetches the repo zip via
`Invoke-WebRequest`, expands it, clears Mark-of-the-Web, and launches the
bootstrap. **No `git` binary is invoked.**

### Option B — you already have the folder locally

If you downloaded the zip manually from GitHub (Code → Download ZIP) and
extracted it, or `git clone`d it: **double-click `bootstrap.cmd`** (or call it
from any shell). It handles MOTW, ExecutionPolicy, and UAC for you.

```cmd
:: From CMD
bootstrap.cmd
```

```powershell
# From PowerShell
.\bootstrap.cmd
```

> ⚠️ Running `bootstrap.ps1` directly is **not recommended** — it only works if
> you're already in PowerShell, ExecutionPolicy allows scripts, and the files
> aren't Mark-of-the-Web blocked. `bootstrap.cmd` removes all three concerns.

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
├── install.cmd                    # Zero-prereq web installer (CMD/PS agnostic)
├── bootstrap.cmd                  # Local launcher: unblocks files + runs .ps1
├── bootstrap.ps1                  # Entry point (self-elevates, self-unblocks)
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
  you ran `bootstrap.ps1` directly. Use `bootstrap.cmd` instead; it sets
  `-ExecutionPolicy Bypass` for the single process.
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

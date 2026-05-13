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

The script makes **no assumptions** about your shell, whether Git is installed, or
whether you downloaded the zip from a browser. Pick whichever option matches how
you got here.

### Option A — zero prereqs (recommended, works in **CMD or PowerShell**)

You don't need Git installed and you don't need to know what shell you're in.
Open **CMD** (Win+R → `cmd`) or **PowerShell** and run:

```cmd
curl -L -o %TEMP%\pmboot.cmd https://raw.githubusercontent.com/vamckMS/pm-hackathon-bootscript/main/install.cmd && %TEMP%\pmboot.cmd
```

`install.cmd` downloads the repo as a zip, clears Mark-of-the-Web, and launches
the bootstrap. Git itself will be installed during the run.

### Option B — you already downloaded / cloned the repo

**Just double-click `bootstrap.cmd`**. It unblocks the files, bypasses execution
policy, and self-elevates.

Or from a shell:

```cmd
:: CMD
bootstrap.cmd
```

```powershell
# PowerShell (5.1 or 7+)
.\bootstrap.cmd
```

> ⚠️ Running `.\bootstrap.ps1` directly only works if (a) you're already in
> PowerShell, (b) `ExecutionPolicy` allows it, and (c) the files don't have
> Mark-of-the-Web. **Use `bootstrap.cmd` and you don't have to think about any
> of that.**

### Option C — you cloned via Git

```powershell
git clone https://github.com/vamckMS/pm-hackathon-bootscript
cd pm-hackathon-bootscript
.\bootstrap.cmd
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

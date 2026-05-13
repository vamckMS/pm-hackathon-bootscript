# Legacy: PM Hackathon Bootstrap script

> ⚠️ **Not the recommended path.** The active guide is at
> [`docs/index.html`](../docs/index.html) (or the GitHub Pages URL — see the
> top-level [`README`](../README.md)).

## Why this exists

This folder preserves the original PowerShell bootstrap that tried to install
the whole PM hackathon toolchain in one shot via:

```powershell
iex "& { $(irm https://raw.githubusercontent.com/vamckMS/pm-hackathon-bootscript/main/legacy/bootstrap.ps1) }"
```

It was architected to be:

- **Idempotent** — detect → act only if needed → verify
- **Self-elevating** via UAC (admin auto-prompt)
- **GPO-immune** — loads scripts via `[ScriptBlock]::Create` from text, so
  Group-Policy-enforced ExecutionPolicy can't block it
- **MOTW-aware** — clears Mark-of-the-Web on its own files before loading
- **Modular** — 9 modules in `modules/`, config in `config/`

## Why it's archived

Windows Defender on Microsoft-managed devices flags the
`Invoke-Expression`/`Invoke-RestMethod` cradle pattern as
**`Trojan:Win32/Powemet.A!gen`** (Threat ID `2147940835`) — heuristically,
not based on what the script does. The pattern is heavily abused by malware,
so Defender treats every instance the same way.

We verified:

- File-content scan via `MpCmdRun.exe -Scan`: **clean**
- AMSI script-content scan: **clean**
- Live command-line invocation: **detected** (Defender alert raised)

So the script itself isn't malicious — Defender flags the command-line
pattern. For our target audience (PMs on default-configured corp laptops),
that's a hard blocker.

## How to run it anyway (advanced)

If you're on an unmanaged dev machine, or you've added an exclusion for this
repo path, you can still use the script:

```powershell
# 1) Clone or download as zip and extract
git clone https://github.com/vamckMS/pm-hackathon-bootscript
cd pm-hackathon-bootscript\legacy

# 2) Double-click bootstrap.cmd
#    OR from any shell:
.\bootstrap.cmd

# 3) Common flags
.\bootstrap.cmd -WhatIf                      # dry run
.\bootstrap.cmd -GithubUsername alice-msft   # provide GH username up front
.\bootstrap.cmd -SkipGhValidation            # skip the GH<->MS link check
.\bootstrap.cmd -Force vscode-extensions     # force-reinstall one module
```

The `.cmd` wrapper handles MOTW (Unblock-File) and ExecutionPolicy bypass via
the same `[ScriptBlock]::Create` trick the in-memory path uses.

## What it installs

Same set as the active guide:

- Package managers: winget primary, Chocolatey fallback
- Core CLIs: Git, Node LTS, Python 3, GitHub CLI
- Terminal: Windows Terminal + PowerShell 7 (added as a WT profile)
- Editor: VS Code + extensions from `config/extensions.json`
- GitHub Copilot CLI: `gh extension install github/gh-copilot`
- GH↔MS account-link validation (3 signals)
- Agency Copilot via its official `aka.ms/InstallTool.ps1` line, with a
  `gh release download` fallback against `ahsi-microsoft/agency-cowork`

## Future

If Defender ever publishes a clean signal for this exact script (signed,
allow-listed by Microsoft, or hosted under an `aka.ms` like Agency does),
this could come back to the main path. Until then, the active guide stays
the recommended path.

# PM Hackathon Setup Guide

Step-by-step instructions to get a Microsoft PM laptop ready for the PM
hackathon — pick your OS + editor, paste the commands, verify each step.

## 👉 Start here

**[https://vamckMS.github.io/pm-hackathon-bootscript/](https://vamckMS.github.io/pm-hackathon-bootscript/)**

The guide covers:

- **Windows / macOS / Linux** package-manager commands (`winget` / `brew` / `apt`)
- **VS Code / CLI-only** editor paths (other editors — PRs welcome)
- Git, Node LTS, Python 3, GitHub CLI
- Windows Terminal + PowerShell 7 (Windows)
- GitHub Copilot in your editor + the standalone `copilot` CLI in your terminal
- GitHub ↔ Microsoft account-link validation (unlocks unlimited Copilot tokens)
- Agency

Each step has a verify command and an expected output so you know it worked.

## Why no script?

The first version of this repo shipped a PowerShell bootstrap launched via
`iex (irm …)`. That pattern is heuristically flagged as
**`Trojan:Win32/Powemet.A!gen`** by Windows Defender on managed Microsoft
machines — even when the script content itself scans clean. We tried in-memory
loading, download-to-file, GPO-immune `[ScriptBlock]::Create`, MOTW handling…
all hit the same heuristic.

So we pivoted to the guide above: plain `winget` / `brew` / `apt` commands
you paste yourself. No download cradle, nothing for Defender to flag.

## Advanced: legacy bootstrap script

If you're on an unmanaged dev machine and want the one-command install
experience anyway, the original script is preserved in
[`/legacy`](./legacy/) with its own [README](./legacy/README.md).

## Contributing

- Tested on Windows. macOS/Linux commands are standard package-manager
  incantations but are unverified. **PRs welcome** if you spot anything off.
- The MCP-server extension list is still a placeholder pending the
  hackathon organizers' final list.

## Source layout

```
.
├── docs/
│   ├── index.html       ← the guide (served via GitHub Pages)
│   └── .nojekyll        ← tells Pages not to run Jekyll
├── legacy/              ← the retired bootstrap script
│   ├── bootstrap.ps1
│   ├── bootstrap.cmd
│   ├── modules/
│   ├── config/
│   └── README.md
└── README.md            ← you are here
```

## License

MIT — see your team's standard license (or add one if missing).

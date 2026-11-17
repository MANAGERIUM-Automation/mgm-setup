# mgm-setup

One-line installer for the Managerium QA automation workspace (GitHub org
`MANAGERIUM-Automation`). No credentials live here.

**Windows** (PowerShell):

```powershell
irm https://raw.githubusercontent.com/MANAGERIUM-Automation/mgm-setup/main/install.ps1 | iex
```

**macOS** (Terminal):

```bash
curl -fsSL https://raw.githubusercontent.com/MANAGERIUM-Automation/mgm-setup/main/install.sh | bash
```

It installs Git, GitHub CLI, Node.js and Python 3.12 if missing, signs you in to GitHub (browser),
clones every `mgm-*` repo side by side into `~/Managerium-QA` (change with `MGM_WORKSPACE`),
creates one Python environment (`.venv`), links the shared parts of `mgm-core` into each repo,
and clones the read-only product source from GitLab (asks for your GitLab login the first time).
Run it again any time to update everything.

Then open **your own repo** in VS Code and start Claude Code there:
`mgm-RTM` (Shawkat), `mgm-web` (Rafsana Kabir Samanta), `mgm-mobileApp` (Rakib). Rules and the folder guide
(Bangla) are in `mgm-core`: `CLAUDE.md`, `STRUCTURE_GUIDELINE.md`.

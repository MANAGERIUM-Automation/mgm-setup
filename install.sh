#!/usr/bin/env bash
# Managerium QA workspace installer for macOS. Run in Terminal:
#   curl -fsSL https://raw.githubusercontent.com/MANAGERIUM-Automation/mgm-setup/main/install.sh | bash
# Run it again any time to update. Workspace folder: $MGM_WORKSPACE, default ~/Managerium-QA.
set -euo pipefail
ORG=MANAGERIUM-Automation
WS="${MGM_WORKSPACE:-$HOME/Managerium-QA}"

# 1. Tools (Homebrew)
if ! command -v brew >/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
fi
for pkg in git gh node python@3.12; do brew list "$pkg" >/dev/null 2>&1 || brew install "$pkg"; done
PY="$(brew --prefix python@3.12)/bin/python3.12"

# 2. GitHub login and git identity
gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web </dev/tty
gh auth setup-git
if [ -z "$(git config --global user.email || true)" ]; then
  read -rp "Your full name for git commits: " name </dev/tty; git config --global user.name "$name"
  read -rp "Your office email for git commits: " mail </dev/tty; git config --global user.email "$mail"
fi

# 3. Repos: every mgm-* repo of the organization, side by side
mkdir -p "$WS/references"; cd "$WS"
repos=$(gh repo list "$ORG" --limit 100 --json name --jq '.[].name' | grep '^mgm-' | grep -v '^mgm-setup$')
for r in $repos; do
  if [ -e "$r" ] && ! git -C "$r" rev-parse --git-dir >/dev/null 2>&1; then
    # A clone that stopped halfway: keep it aside (nothing is deleted) and clone again.
    aside="$r.broken-$(date +%Y%m%d%H%M%S)"; echo "WARNING: $r is not a working git repo; moved to $aside"
    mv "$r" "$aside"
  fi
  if [ -d "$r" ]; then git -C "$r" pull --ff-only --quiet || echo "WARNING: $r not updated"
  else gh repo clone "$ORG/$r" "$r" -- --quiet || echo "WARNING: $r not cloned"; fi
done

# 4. One Python environment for the workspace
[ -d .venv ] || "$PY" -m venv .venv
.venv/bin/python -m pip install --quiet --upgrade pip
.venv/bin/python -m pip install --quiet -e "./mgm-core[dev,mobile]"
.venv/bin/python -m playwright install chromium

# 5. Shared parts are links into mgm-core and references (git-ignored in every repo)
link() { [ -e "$1" ] || ln -s "$2" "$1"; }
link mgm-core/references ../references
git -C mgm-core config core.hooksPath .githooks
for r in $repos; do
  [ "$r" = mgm-core ] && continue
  mkdir -p "$r/.claude"
  link "$r/references" ../references
  link "$r/tools" ../mgm-core/tools
  link "$r/.claude/commands" ../../mgm-core/.claude/commands
  link "$r/.claude/agents" ../../mgm-core/.claude/agents
  git -C "$r" config core.hooksPath ../mgm-core/.githooks
done

# 6. Product source (GitLab, read-only); asks for GitLab login the first time
bash mgm-core/tools/setup-references.sh </dev/tty || echo "WARNING: references not updated (rerun mgm-core/tools/setup-references.sh later)"

echo; echo "Done. Workspace: $WS"
echo "Open YOUR repo in VS Code and start Claude there, e.g.:  code \"$WS/mgm-web\""

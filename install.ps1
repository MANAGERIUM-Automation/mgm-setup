# Managerium QA workspace installer for Windows. Run in PowerShell:
#   irm https://raw.githubusercontent.com/MANAGERIUM-Automation/mgm-setup/main/install.ps1 | iex
# Run it again any time to update. Workspace folder: $env:MGM_WORKSPACE, default ~\Managerium-QA.
# Continue: native tools write progress to stderr; each step checks $LASTEXITCODE itself.
$ErrorActionPreference = 'Continue'
$Org = 'MANAGERIUM-Automation'
$Ws = if ($env:MGM_WORKSPACE) { $env:MGM_WORKSPACE } else { Join-Path $HOME 'Managerium-QA' }

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Need($cmd, $id) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) { return }
    Write-Host "Installing $id ..."
    winget install --id $id -e --silent --accept-source-agreements --accept-package-agreements
    Refresh-Path
}
function Link($path, $target) {
    if (-not (Test-Path $path)) { New-Item -ItemType Junction -Path $path -Target $target | Out-Null }
}

# 1. Tools
Need git Git.Git
Need gh GitHub.cli
Need node OpenJS.NodeJS.LTS
& py -3.12 --version *> $null
if ($LASTEXITCODE -ne 0) { winget install --id Python.Python.3.12 -e --silent --accept-source-agreements --accept-package-agreements; Refresh-Path }

# 2. GitHub login and git identity
& gh auth status *> $null
if ($LASTEXITCODE -ne 0) { gh auth login --hostname github.com --git-protocol https --web }
gh auth setup-git
if (-not (git config --global user.email)) {
    git config --global user.name (Read-Host 'Your full name for git commits')
    git config --global user.email (Read-Host 'Your office email for git commits')
}

# 3. Repos: every mgm-* repo of the organization, side by side
New-Item -ItemType Directory -Force $Ws, "$Ws\references" | Out-Null
Set-Location $Ws
$repos = gh repo list $Org --limit 100 --json name --jq '.[].name' | Where-Object { $_ -like 'mgm-*' -and $_ -ne 'mgm-setup' }
foreach ($r in $repos) {
    if (Test-Path $r) {
        & git -C $r rev-parse --git-dir *> $null
        if ($LASTEXITCODE -ne 0) {
            # A clone that stopped halfway: keep it aside (nothing is deleted) and clone again.
            $aside = "$r.broken-$(Get-Date -Format yyyyMMddHHmmss)"
            Write-Warning "$r is not a working git repo; moved to $aside and cloning again"
            Rename-Item $r $aside
        }
    }
    if (Test-Path $r) { git -C $r pull --ff-only --quiet } else { gh repo clone "$Org/$r" $r -- --quiet }
    if ($LASTEXITCODE -ne 0) { Write-Warning "$r could not be cloned / updated" }
}

# 4. One Python environment for the workspace
if (-not (Test-Path .venv)) { py -3.12 -m venv .venv }
.\.venv\Scripts\python -m pip install --quiet --upgrade pip
.\.venv\Scripts\python -m pip install --quiet -e ".\mgm-core[dev,mobile]"
.\.venv\Scripts\python -m playwright install chromium

# 5. Shared parts are links into mgm-core and references (git-ignored in every repo)
Link "$Ws\mgm-core\references" "$Ws\references"
git -C mgm-core config core.hooksPath .githooks
foreach ($r in $repos | Where-Object { $_ -ne 'mgm-core' }) {
    New-Item -ItemType Directory -Force "$Ws\$r\.claude" | Out-Null
    Link "$Ws\$r\references" "$Ws\references"
    Link "$Ws\$r\tools" "$Ws\mgm-core\tools"
    Link "$Ws\$r\.claude\commands" "$Ws\mgm-core\.claude\commands"
    Link "$Ws\$r\.claude\agents" "$Ws\mgm-core\.claude\agents"
    git -C $r config core.hooksPath ../mgm-core/.githooks
}

# 6. Product source (GitLab, read-only); asks for GitLab login the first time
try { powershell -NoProfile -ExecutionPolicy Bypass -File "$Ws\mgm-core\tools\setup-references.ps1" }
catch { Write-Warning "references not updated: $_  (rerun mgm-core\tools\setup-references.ps1 later)" }

Write-Host "`nDone. Workspace: $Ws"
Write-Host "Open YOUR repo in VS Code and start Claude there, e.g.:  code `"$Ws\mgm-web`""

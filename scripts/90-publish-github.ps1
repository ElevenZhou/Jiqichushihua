param(
  [string]$Owner = "",
  [string]$RepoName = "Jiqichushihua",
  [string]$RemoteUrl = "",
  [string]$Branch = "master"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".git")) {
  throw "Run this script from the repository root."
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw "GitHub CLI gh is not installed."
}

gh auth status
if ($LASTEXITCODE -ne 0) {
  throw "GitHub CLI is not authenticated. Run: gh auth login -h github.com"
}

$existingRemote = ""
$remoteExitCode = 0
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$existingRemote = git remote get-url origin 2>$null
$remoteExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference

if ($RemoteUrl) {
  if ($remoteExitCode -eq 0 -and $existingRemote) {
    git remote set-url origin $RemoteUrl
  } else {
    git remote add origin $RemoteUrl
  }

  git push -u origin $Branch
  exit 0
}

if ([string]::IsNullOrWhiteSpace($Owner)) {
  throw "Owner is required when RemoteUrl is not provided. Example: -Owner ElevenZhou -RepoName Jiqichushihua"
}

if ($remoteExitCode -eq 0 -and $existingRemote) {
  git push -u origin $Branch
  exit 0
}

gh repo create "$Owner/$RepoName" --public --source . --remote origin --push

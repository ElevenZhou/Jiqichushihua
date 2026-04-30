param(
  [string]$ConfigPath = "..\templates\machine-config.example.ps1"
)

$ErrorActionPreference = "Stop"

if (-not [System.IO.Path]::IsPathRooted($ConfigPath)) {
  $ConfigPath = Join-Path $PSScriptRoot $ConfigPath
}

. $ConfigPath

function Sync-Repo {
  param(
    [string]$Name,
    [string]$Url,
    [string]$Path
  )

  if ([string]::IsNullOrWhiteSpace($Url)) {
    Write-Warning "$Name repo URL is empty; skipping."
    return
  }

  if (Test-Path (Join-Path $Path ".git")) {
    Write-Host "Updating $Name at $Path"
    git -C $Path pull --ff-only
    return
  }

  if (Test-Path $Path) {
    $items = Get-ChildItem -Force -Path $Path
    if ($items.Count -gt 0) {
      throw "$Name target exists and is not an empty git repo: $Path"
    }
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
  }

  Write-Host "Cloning $Name to $Path"
  git clone $Url $Path
}

Sync-Repo -Name "claude-workspace" -Url $ClaudeWorkspaceRepo -Path $ClaudeWorkspacePath
Sync-Repo -Name "secrets-backup" -Url $SecretsBackupRepo -Path $SecretsRoot

Write-Host "Repository sync finished."

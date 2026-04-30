param(
  [string]$ConfigPath = "..\templates\machine-config.example.ps1"
)

$ErrorActionPreference = "Stop"

if (-not [System.IO.Path]::IsPathRooted($ConfigPath)) {
  $ConfigPath = Join-Path $PSScriptRoot $ConfigPath
}

. $ConfigPath

$folders = @(
  $WorkspaceRoot,
  (Join-Path $WorkspaceRoot "ops"),
  (Join-Path $WorkspaceRoot "ops\claude-relay"),
  $RedisDataDir,
  $RedisBackupDir,
  $SecretsRoot
)

foreach ($folder in $folders) {
  New-Item -ItemType Directory -Force -Path $folder | Out-Null
  Write-Host "OK $folder"
}

Write-Host "Folder initialization finished."

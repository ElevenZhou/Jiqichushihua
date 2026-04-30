param(
  [string]$ConfigPath = "..\templates\machine-config.example.ps1"
)

$ErrorActionPreference = "Stop"

if (-not [System.IO.Path]::IsPathRooted($ConfigPath)) {
  $ConfigPath = Join-Path $PSScriptRoot $ConfigPath
}

if (-not (Test-Path $ConfigPath)) {
  throw "Config file not found: $ConfigPath"
}

. $ConfigPath

Write-Host "Machine number: $MachineNo"
Write-Host "Workspace root: $WorkspaceRoot"
Write-Host "Secrets root: $SecretsRoot"
Write-Host "Relay repo: $ClaudeWorkspaceRepo"
Write-Host "Secrets repo: $SecretsBackupRepo"

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isAdmin) {
  Write-Host "PowerShell privilege: Administrator"
} else {
  Write-Warning "PowerShell privilege: normal user. NSSM service install and some installers require Administrator."
}

$requiredDrive = Split-Path -Qualifier $WorkspaceRoot
if (-not (Test-Path $requiredDrive)) {
  throw "Required drive not found: $requiredDrive"
}

Write-Host "Prerequisite check finished."

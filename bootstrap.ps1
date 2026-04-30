param(
  [int]$MachineNo = 0,
  [string]$ConfigPath = ".\templates\machine-config.example.ps1",
  [switch]$InstallTools,
  [switch]$CloneRepos,
  [switch]$VerifyOnly
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Invoke-Step {
  param(
    [string]$Name,
    [string]$Script,
    [string[]]$Args = @()
  )

  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script @Args
}

if (-not (Test-Path $ConfigPath)) {
  throw "Config file not found: $ConfigPath"
}

$resolvedConfig = (Resolve-Path $ConfigPath).Path

if ($VerifyOnly) {
  Invoke-Step "Verify environment" ".\scripts\04-verify-env.ps1" @("-ConfigPath", $resolvedConfig)
  exit 0
}

Invoke-Step "Check prerequisites" ".\scripts\00-check-prereqs.ps1" @("-ConfigPath", $resolvedConfig)

if ($InstallTools) {
  Invoke-Step "Install base tools with winget" ".\scripts\01-install-base-tools.ps1"
}

Invoke-Step "Initialize folders" ".\scripts\02-init-folders.ps1" @("-ConfigPath", $resolvedConfig)

if ($CloneRepos) {
  Invoke-Step "Clone required repositories" ".\scripts\03-clone-required-repos.ps1" @("-ConfigPath", $resolvedConfig)
}

Invoke-Step "Verify environment" ".\scripts\04-verify-env.ps1" @("-ConfigPath", $resolvedConfig)

Write-Host ""
Write-Host "Bootstrap finished. Continue with the SOP document:" -ForegroundColor Green
Write-Host "  .\Windows机器初始化-claude-relay标准SOP.md"


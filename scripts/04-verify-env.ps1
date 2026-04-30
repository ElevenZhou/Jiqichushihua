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

$ErrorActionPreference = "Continue"

$checks = @(
  @{ Name = "git"; Command = "git"; Args = @("--version") },
  @{ Name = "node"; Command = "node"; Args = @("-v") },
  @{ Name = "npm.cmd"; Command = "npm.cmd"; Args = @("-v") },
  @{ Name = "docker"; Command = "docker"; Args = @("--version") }
)

$failed = 0

foreach ($check in $checks) {
  $cmd = Get-Command $check.Command -ErrorAction SilentlyContinue
  if (-not $cmd) {
    Write-Host "FAIL $($check.Name): not found" -ForegroundColor Red
    $failed++
    continue
  }

  $output = & $check.Command @($check.Args) 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Host "OK $($check.Name): $output" -ForegroundColor Green
  } else {
    Write-Host "FAIL $($check.Name): $output" -ForegroundColor Red
    $failed++
  }
}

foreach ($path in @($WorkspaceRoot, $RedisDataDir, $RedisBackupDir)) {
  if (Test-Path $path) {
    Write-Host "OK path: $path" -ForegroundColor Green
  } else {
    Write-Host "FAIL path missing: $path" -ForegroundColor Red
    $failed++
  }
}

if (Test-Path $ClaudeRelayServicePath) {
  Write-Host "OK relay service path: $ClaudeRelayServicePath" -ForegroundColor Green
} else {
  Write-Host "WARN relay service path missing: $ClaudeRelayServicePath" -ForegroundColor Yellow
}

docker ps 1>$null 2>$null
if ($LASTEXITCODE -eq 0) {
  Write-Host "OK Docker daemon is reachable." -ForegroundColor Green
} else {
  Write-Host "WARN Docker daemon is not reachable. Start Docker Desktop before Redis setup." -ForegroundColor Yellow
}

if ($failed -gt 0) {
  throw "$failed required checks failed."
}

Write-Host "Environment verification finished."

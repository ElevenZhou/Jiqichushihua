$ErrorActionPreference = "Stop"

function Install-WingetPackage {
  param(
    [string]$Id,
    [string]$Name
  )

  Write-Host "Checking $Name..."
  $existing = winget list --id $Id -e 2>$null
  if ($LASTEXITCODE -eq 0 -and ($existing -match [regex]::Escape($Id))) {
    Write-Host "$Name already installed."
    return
  }

  Write-Host "Installing $Name..."
  winget install --id $Id -e --accept-package-agreements --accept-source-agreements
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  throw "winget not found. Install App Installer from Microsoft Store or use offline installers in this folder."
}

Install-WingetPackage -Id "Git.Git" -Name "Git"
Install-WingetPackage -Id "OpenJS.NodeJS.LTS" -Name "Node.js LTS"
Install-WingetPackage -Id "Docker.DockerDesktop" -Name "Docker Desktop"
Install-WingetPackage -Id "Microsoft.VisualStudioCode" -Name "VS Code"
Install-WingetPackage -Id "Microsoft.WindowsTerminal" -Name "Windows Terminal"

Write-Host "Base tool installation step finished. Start Docker Desktop manually once if docker ps cannot connect."


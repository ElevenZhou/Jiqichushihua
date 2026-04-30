# Required Installers Manifest

This repository tracks offline installer binaries with Git LFS, so new machines do not need to download them separately.

Before pushing to GitHub, make sure Git LFS is enabled:

```powershell
git lfs install
git lfs ls-files
```

## Currently Present Locally

| File | Purpose | Commit method |
| --- | --- | --- |
| `Git-2.54.0-64-bit.exe` | Git | Git LFS |
| `VSCodeSetup-x64-1.117.0.exe` | VS Code | Git LFS |
| `OpenCode Desktop Installer.exe` | AI-assisted local operations | Git LFS |
| `CC-Switch-v3.14.1-Windows.msi` | Claude Code / model account switch helper | Git LFS |
| `uuyc_4.21.0 (1).exe` | Remote/admin helper | Git LFS |

## Should Be Added Locally Or Installed By Script

| Tool | Preferred install method | Notes |
| --- | --- | --- |
| Node.js LTS | `winget install --id OpenJS.NodeJS.LTS -e` | Required |
| Docker Desktop | `winget install --id Docker.DockerDesktop -e` | Required |
| NSSM | Offline zip or ops package | Required for Windows services |
| frp Windows amd64 | Offline zip or ops package | Required for frpc |
| Redis image | `docker pull redis:7.2-alpine` or offline image | Required by service |
| Windows Terminal | `winget install --id Microsoft.WindowsTerminal -e` | Optional |

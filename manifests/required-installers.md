# Required Installers Manifest

This repository is intended to be public, so large installer binaries are ignored by git.

Keep offline installers in `D:\Jiqichushihua` only when needed, or publish them as GitHub Release assets instead of committing them.

## Currently Present Locally

| File | Purpose | Commit to public git |
| --- | --- | --- |
| `Git-2.54.0-64-bit.exe` | Git | No |
| `VSCodeSetup-x64-1.117.0.exe` | VS Code | No |
| `OpenCode Desktop Installer.exe` | AI-assisted local operations | No |
| `CC-Switch-v3.14.1-Windows.msi` | Claude Code / model account switch helper | No |
| `uuyc_4.21.0 (1).exe` | Remote/admin helper | No |

## Should Be Added Locally Or Installed By Script

| Tool | Preferred install method | Notes |
| --- | --- | --- |
| Node.js LTS | `winget install --id OpenJS.NodeJS.LTS -e` | Required |
| Docker Desktop | `winget install --id Docker.DockerDesktop -e` | Required |
| NSSM | Offline zip or ops package | Required for Windows services |
| frp Windows amd64 | Offline zip or ops package | Required for frpc |
| Redis image | `docker pull redis:7.2-alpine` or offline image | Required by service |
| Windows Terminal | `winget install --id Microsoft.WindowsTerminal -e` | Optional |


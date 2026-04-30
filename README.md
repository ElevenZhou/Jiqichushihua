# 机器初始化文档

本目录用于保存新 Windows 机器接入 `claude-relay-service` 集群的标准化资料。

这个目录可以作为公开 Git 仓库使用。公开仓库只提交文档、脚本、模板和安装清单；不要提交安装包二进制、真实 token、webhook、密码、`.env`、`init.json`、`frpc.toml`。

适用目标：

- 全新 Windows 机器从零部署 `claude-relay-service`
- 使用 Docker Redis
- 使用 frpc 接入 60 机器
- 使用 NSSM 托管 Windows 服务
- 最终交给总调度机器统一接管和监控

当前文档：

| 文件 | 作用 |
| --- | --- |
| `Windows机器初始化-claude-relay标准SOP.md` | 新机器从零上线、服务化、验收、交接总调度、运维、更新、备份、迁移、下线、故障分流的流程总册 |
| `bootstrap.ps1` | 新机器初始化入口脚本 |
| `scripts/` | 分步骤自动化脚本 |
| `templates/machine-config.example.ps1` | 机器配置模板 |
| `manifests/required-installers.md` | 安装包和工具清单 |

## 快速开始

新机器先拉这个公开初始化库：

```powershell
cd D:\
git clone <这个公开初始化仓库URL> Jiqichushihua
cd D:\Jiqichushihua
```

如果需要修改仓库地址或机器参数：

```powershell
Copy-Item .\templates\machine-config.example.ps1 .\machine-config.ps1
notepad .\machine-config.ps1
```

只检查环境：

```powershell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -ConfigPath .\machine-config.ps1 -VerifyOnly
```

联网机器自动安装基础工具、创建目录、拉取另外两个库：

```powershell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -ConfigPath .\machine-config.ps1 -InstallTools -CloneRepos
```

如果基础软件已经装好，只创建目录并拉取另外两个库：

```powershell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -ConfigPath .\machine-config.ps1 -CloneRepos
```

后续部署 `claude-relay-service`、Redis、frpc、NSSM、飞书和总调度接管，继续按：

```text
Windows机器初始化-claude-relay标准SOP.md
```

## 需要配合拉取的另外两个库

建议新机器最终准备三个库/目录：

| 目录 | 类型 | 说明 |
| --- | --- | --- |
| `D:\Jiqichushihua` | 公开初始化库 | 文档、脚本、模板、安装清单 |
| `D:\Projects\claude-workspace` | 公开业务代码库 | `claude-relay-service` 代码 |
| `D:\secrets-backup` | 私密配置库 | `.env`、`init.json`、frpc token、飞书配置、ops 模板 |

`D:\secrets-backup` 不应该公开。

流程覆盖：

1. 机器编号和端口规划。
2. 初始化安装包盘点。
3. 必装运行环境。
4. AI 自动化管理环境。
5. 新 Windows 机器初始化。
6. `claude-relay-service` 部署。
7. Docker Redis 初始化。
8. frpc 接入 60 机器。
9. NSSM 服务化。
10. 飞书通知。
11. 60 机器交接。
12. 总调度机器接管。
13. 私密库备份。
14. 日常运维。
15. 代码更新。
16. Redis 备份和恢复。
17. 整机迁移。
18. 节点下线。
19. 故障分流。

当前目录已有安装包：

| 安装包 | 作用 |
| --- | --- |
| `Git-2.54.0-64-bit.exe` | Git 环境 |
| `VSCodeSetup-x64-1.117.0.exe` | 本机代码/配置编辑 |
| `OpenCode Desktop Installer.exe` | AI 辅助开发/运维 |
| `CC-Switch-v3.14.1-Windows.msi` | Claude Code / 模型账号切换类工具 |
| `uuyc_4.21.0 (1).exe` | 远程/辅助管理工具 |

建议补齐：

```text
Node.js LTS installer
Docker Desktop installer
NSSM zip
frp Windows amd64 zip
Redis 镜像离线包，可选
Windows Terminal，可选
```

重要原则：

1. 每台机器独立生成 `.env` 和 `data\init.json`。
2. 每台机器使用唯一的 frpc `name` 和 `remotePort`。
3. 公网入口只走 60 机器 Caddy，不直接开放 frpc `remotePort`。
4. 本目录可放初始化文档和安装包，但不要放真实 token、webhook、密码。
5. 真实敏感配置应放在私密库，例如 `D:\secrets-backup`。
6. 安装包二进制默认不提交到公开 Git；需要离线分发时，优先用 GitHub Releases 或单独网盘。

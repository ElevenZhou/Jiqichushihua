# Windows 机器初始化 - claude-relay-service 流程总册

本文档整理一台全新 Windows 机器从零初始化、部署 `claude-relay-service`、接入 frpc、服务化、验收、交给总调度机器接管，以及后续运维、更新、备份、迁移、下线的完整流程。

本文档不保存真实 token、webhook、密码、管理员口令。真实敏感配置只放私密库，例如 `D:\secrets-backup`。

## 0. 总体架构

目标链路：

```text
用户请求
  -> apiX.yumiai.art
  -> 60 机器 Caddy
  -> 127.0.0.1:<remotePort>
  -> frps
  -> 目标 Windows 机器 frpc
  -> 127.0.0.1:3001
  -> claude-relay-service
  -> Docker Redis 127.0.0.1:6380
```

目标机器本地形态：

```text
D:\Projects\claude-workspace\claude-relay-service
D:\Projects\ops\claude-relay
D:\redis-data
D:\redis-backup

NSSM service: claude-relay-service
NSSM service: frpc
Docker container: claude-redis
```

职责边界：

| 角色 | 负责 | 不负责 |
| --- | --- | --- |
| Windows 节点部署人 | 本机环境、服务、Redis、frpc、NSSM、飞书通知 | 不直接改 60 机器 Caddy/DNS/防火墙 |
| 60 机器运维 | Caddy、DNS、frps、公网入口、remotePort 回环代理 | 不登录每台 Windows 机器改本地服务 |
| 总调度机器 | 节点登记、健康检查、接管、切流、告警、状态记录 | 不保存明文业务密钥 |
| 私密库维护人 | `.env`、`init.json`、frpc token、飞书 webhook 备份 | 不把敏感文件放公开仓库 |

## 1. 机器编号和端口规划

每台机器上线前必须先分配机器编号，不允许临时混用端口。

| 机器 | 本地端口 | Redis 端口 | frpc name | remotePort | 域名 |
| --- | --- | --- | --- | --- | --- |
| N3 | 3001 | 6380 | `yumiai-3` | 13002 | `api3.yumiai.art` |
| N4 | 3001 | 6380 | `yumiai-4` | 13003 | `api4.yumiai.art` |
| N5 | 3001 | 6380 | `yumiai-5` | 13004 | `api5.yumiai.art` |
| N6 | 3001 | 6380 | `yumiai-6` | 13005 | `api6.yumiai.art` |

规则：

1. 每台 Windows 是独立机器，本地服务端口统一用 `3001`。
2. 每台 Windows 的 Redis 统一用 `127.0.0.1:6380`。
3. frpc `name` 必须唯一。
4. 60 机器上的 `remotePort` 必须唯一。
5. `remotePort` 不对公网开放，只给 60 机器 Caddy 本机回环使用。
6. 公网入口只走 `https://apiX.yumiai.art`，不要直接暴露 `remotePort`。

上线登记模板：

```text
机器编号:
Windows 主机名:
机器用途: 生产 / 测试 / 备用
本地服务: http://127.0.0.1:3001
本地后台: http://127.0.0.1:3001/admin-next/
Redis: 127.0.0.1:6380
frpc name:
remotePort:
公网域名:
部署人:
部署时间:
私密库备份位置:
备注:
```

## 2. 新机上线总流程

标准顺序：

```text
1. 分配机器编号和 remotePort
2. 安装基础软件
3. 准备目录
4. 拉取公开代码
5. 安装依赖和构建后台
6. 独立生成 .env 和 data\init.json
7. 启动 Docker Redis
8. 配置 frpc
9. 准备 ops wrapper 和飞书配置
10. 手动启动本地服务和 frpc
11. 本地验收
12. NSSM 服务化
13. 飞书通知验收
14. 交给 60 机器运维配置 Caddy/DNS
15. 公网验收
16. 登记到总调度机器
17. 备份敏感配置到私密库
```

任何一步失败，不进入下一步。

## 3. 基础软件和 AI 自动化环境安装流程

`D:\Jiqichushihua` 是新机器初始化工具箱，应该同时满足两件事：

1. 让 `claude-relay-service` 能稳定运行。
2. 让 AI 可以远程查看、执行命令、编辑文件、自动化部署和日常管理。

### 3.1 当前目录已有安装包

当前 `D:\Jiqichushihua` 已有：

| 安装包 | 类型 | 作用 | 部署优先级 |
| --- | --- | --- | --- |
| `Git-2.54.0-64-bit.exe` | 必装 | 拉取代码、更新代码、版本确认 | P0 |
| `VSCodeSetup-x64-1.117.0.exe` | 建议安装 | 本机查看和编辑代码、文档、配置 | P1 |
| `OpenCode Desktop Installer.exe` | AI 工具 | 方便本机使用 AI 辅助开发/运维 | P1 |
| `CC-Switch-v3.14.1-Windows.msi` | AI/账号工具 | Claude Code / 模型账号切换类工具，便于 AI 工作流 | P1 |
| `uuyc_4.21.0 (1).exe` | 远程/辅助工具 | 远程连接或辅助管理，按实际用途配置 | P2 |

当前目录缺少但这套流程需要的包：

| 缺失项 | 类型 | 为什么需要 |
| --- | --- | --- |
| Node.js LTS installer | 必装 | 运行 `claude-relay-service` 和 `npm.cmd install/build` |
| Docker Desktop installer | 必装 | 运行 Docker Redis 7.2 |
| NSSM zip | 必装 | 把 Node 服务和 frpc 托管成 Windows 服务 |
| frp Windows amd64 zip | 必装 | 提供 `frpc.exe` 接入 60 机器 frps |
| Redis 镜像离线包，可选 | 可选 | 无网络环境下导入 `redis:7.2-alpine` |
| Windows Terminal，可选 | 可选 | 更好地执行 PowerShell 运维命令 |

如果新机器能联网，缺失项可以用 `winget` 或浏览器下载；如果新机器不能稳定联网，应提前把这些安装包补进 `D:\Jiqichushihua`。

### 3.2 必装运行环境

必须安装：

```text
Git
Node.js LTS
Docker Desktop
NSSM
frp / frpc
```

建议安装：

```text
VS Code
OpenCode Desktop
CC-Switch
远程管理工具
Windows Terminal
```

不建议依赖：

```text
旧 Microsoft Redis 3.x
全局 pm2
手动后台 node 进程
手动后台 frpc 进程
```

### 3.3 推荐安装顺序

按这个顺序安装，减少后续排错：

```text
1. Git
2. Node.js LTS
3. Docker Desktop
4. VS Code
5. OpenCode Desktop / CC-Switch / 远程管理工具
6. 解压 frp 到 D:\Projects\claude-workspace\frp_0.68.1_windows_amd64
7. 解压 NSSM 到固定工具目录，或由 ops 脚本引用
8. 重启 PowerShell，验证 PATH
9. 启动 Docker Desktop，验证 docker ps
```

### 3.4 可用安装命令

Git 安装包已在目录中，可以手动安装；如需静默安装，可尝试：

```powershell
Start-Process -FilePath "D:\Jiqichushihua\Git-2.54.0-64-bit.exe" -ArgumentList "/VERYSILENT","/NORESTART" -Wait
```

VS Code 安装包已在目录中，可以手动安装；如需静默安装，可尝试：

```powershell
Start-Process -FilePath "D:\Jiqichushihua\VSCodeSetup-x64-1.117.0.exe" -ArgumentList "/VERYSILENT","/NORESTART","/MERGETASKS=!runcode" -Wait
```

MSI 安装包示例：

```powershell
msiexec.exe /i "D:\Jiqichushihua\CC-Switch-v3.14.1-Windows.msi" /qn /norestart
```

OpenCode Desktop 和 uuyc 的静默参数需要按安装器实际支持情况确认；不确定时先手动安装，避免半安装状态影响后续部署。

如果机器联网，也可以用 `winget` 安装缺失项：

```powershell
winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
winget install --id Docker.DockerDesktop -e --accept-package-agreements --accept-source-agreements
```

安装 Docker Desktop 后，必须启动一次 Docker Desktop 并等待 daemon 可用。

### 3.5 AI 自动化管理所需环境

为了让 AI 可以稳定接管部署和管理，新机器至少要满足：

```text
PowerShell 可运行脚本
Git 在 PATH 中
node 和 npm.cmd 在 PATH 中
docker 在 PATH 中
D:\Projects 可写
D:\secrets-backup 可访问，或能从私密库拉取
D:\Jiqichushihua 有初始化文档和安装包
远程登录方式可用
飞书通知可用
```

建议开启或确认：

```powershell
Get-ExecutionPolicy -List
```

执行本流程里的脚本时统一使用：

```powershell
powershell -ExecutionPolicy Bypass -File <script.ps1>
```

这样不需要全局降低机器的 PowerShell 执行策略。

### 3.6 安装完成验证

安装完成后打开新的 PowerShell，验证：

```powershell
node -v
npm.cmd -v
git --version
docker --version
docker ps
```

如果 `docker ps` 报 daemon 连接失败，先启动 Docker Desktop。

如果 PowerShell 运行 `npm` 报执行策略错误，统一使用：

```powershell
npm.cmd -v
```

确认常用目录可写：

```powershell
New-Item -ItemType Directory -Force D:\Projects
New-Item -ItemType Directory -Force D:\Projects\ops
New-Item -ItemType Directory -Force D:\redis-data
New-Item -ItemType Directory -Force D:\redis-backup
```

## 4. 目录初始化流程

标准目录：

```text
D:\Projects
D:\Projects\claude-workspace
D:\Projects\ops
D:\Projects\ops\claude-relay
D:\redis-data
D:\redis-backup
D:\secrets-backup
```

创建基础目录：

```powershell
New-Item -ItemType Directory -Force D:\Projects
New-Item -ItemType Directory -Force D:\Projects\ops
New-Item -ItemType Directory -Force D:\redis-data
New-Item -ItemType Directory -Force D:\redis-backup
```

目录分工：

| 目录 | 作用 |
| --- | --- |
| `D:\Projects\claude-workspace` | 公开代码仓库 |
| `D:\Projects\ops\claude-relay` | 本机运维 wrapper、NSSM 安装脚本、飞书脚本 |
| `D:\redis-data` | Redis 持久化数据 |
| `D:\redis-backup` | Redis 备份 |
| `D:\secrets-backup` | 私密配置备份 |
| `D:\Jiqichushihua` | 初始化文档和安装包 |

## 5. 代码拉取流程

拉取公开代码：

```powershell
cd D:\Projects
git clone https://github.com/ElevenZhou/claude-workspace.git claude-workspace
cd D:\Projects\claude-workspace
git pull --ff-only
```

只部署：

```text
D:\Projects\claude-workspace\claude-relay-service
```

不要部署旧的一号项目 `claude-relay` / `clay-server`，除非另有明确要求。

代码更新原则：

1. 普通更新使用 `git pull --ff-only`。
2. 不在生产机器上做开发修改。
3. 不把 `.env`、`init.json`、`frpc.toml`、飞书配置提交到公开仓库。
4. 更新前先记录当前 commit。

查看 commit：

```powershell
cd D:\Projects\claude-workspace
git rev-parse HEAD
git status --short
```

## 6. 依赖安装和后台构建流程

安装服务依赖：

```powershell
cd D:\Projects\claude-workspace\claude-relay-service
npm.cmd install
```

构建后台：

```powershell
cd D:\Projects\claude-workspace\claude-relay-service\web\admin-spa
npm.cmd install
npm.cmd run build
cd ..\..
```

如果普通权限无法写 `node_modules` 或 npm cache，用管理员 PowerShell 执行。

验证：

```powershell
Test-Path D:\Projects\claude-workspace\claude-relay-service\node_modules
Test-Path D:\Projects\claude-workspace\claude-relay-service\web\admin-spa\dist
```

## 7. 独立配置生成流程

每台机器必须独立生成配置。

```powershell
cd D:\Projects\claude-workspace\claude-relay-service
Copy-Item config\config.example.js config\config.js -Force
npm.cmd run setup
```

生成文件：

```text
D:\Projects\claude-workspace\claude-relay-service\.env
D:\Projects\claude-workspace\claude-relay-service\data\init.json
```

`.env` 基础项：

```env
PORT=3001
REDIS_HOST=127.0.0.1
REDIS_PORT=6380
REDIS_DB=0
REDIS_PASSWORD=
NODE_ENV=production
```

原则：

1. 新机器不要复制 N3 的 `.env` 和 `data\init.json`。
2. `.env` 包含 `JWT_SECRET`、`ENCRYPTION_KEY`，必须独立生成。
3. `data\init.json` 包含后台管理员账号密码，必须妥善备份。
4. 只有在明确做“整机克隆/迁移”时，才允许复制旧机器配置。

## 8. Redis 初始化流程

启动 Docker Redis：

```powershell
docker run -d `
  --name claude-redis `
  --restart unless-stopped `
  -p 127.0.0.1:6380:6379 `
  -v D:\redis-data:/data `
  redis:7.2-alpine redis-server --save 60 1000 --dir /data --dbfilename dump.rdb
```

验证：

```powershell
docker ps --filter "name=claude-redis"
docker exec claude-redis redis-cli ping
docker exec claude-redis redis-cli dbsize
```

预期：

```text
PONG
0 或实际 key 数量
```

Redis 原则：

1. 使用 Docker Redis 7.2。
2. 不使用旧 Microsoft Redis 3.x。
3. Redis 只绑定 `127.0.0.1:6380`。
4. 不把 Redis 端口开放到公网。
5. `D:\redis-data` 可能包含业务数据和 token，按敏感数据处理。

## 9. frpc 配置流程

frpc 标准目录：

```text
D:\Projects\claude-workspace\frp_0.68.1_windows_amd64
```

配置文件：

```text
D:\Projects\claude-workspace\frp_0.68.1_windows_amd64\frpc.toml
```

N4 示例：

```toml
serverAddr = "43.134.187.60"
serverPort = 7000
auth.method = "token"
auth.token = "<从私密库复制 frps token>"
transport.tcpMux = true
transport.poolCount = 10
transport.heartbeatInterval = 30
transport.heartbeatTimeout = 90

[[proxies]]
name = "yumiai-4"
type = "tcp"
localIP = "127.0.0.1"
localPort = 3001
remotePort = 13003
```

上线 N5/N6 时改：

```text
name
remotePort
域名登记信息
```

验证 frpc：

```powershell
D:\Projects\claude-workspace\frp_0.68.1_windows_amd64\frpc.exe -c D:\Projects\claude-workspace\frp_0.68.1_windows_amd64\frpc.toml
```

预期日志：

```text
login to server success
start proxy success
```

常见错误：

| 错误 | 含义 | 处理 |
| --- | --- | --- |
| token 错误 | frpc token 和 frps 不一致 | 从私密库复制正确 token |
| name already in use | frpc name 冲突 | 换成当前机器唯一 name |
| remote port already used | remotePort 冲突 | 换成规划表中的端口 |
| connect timeout | 访问不到 60 机器 frps | 检查网络和 60 机器 frps |

## 10. ops wrapper 和飞书流程

标准 ops 目录：

```text
D:\Projects\ops\claude-relay
```

从私密库或 N3 模板复制：

```powershell
Copy-Item -Recurse D:\secrets-backup\N3\ops D:\Projects\ops\claude-relay -Force
```

需要检查的文件：

```text
run-service.ps1
run-frpc.ps1
install-nssm.ps1
send-feishu.ps1
feishu-config.ps1
```

必须修改：

```text
机器编号
frpc 路径
服务路径
日志路径
飞书 webhook
飞书 secret
```

飞书配置属于敏感配置，只进入私密库，不进入公开仓库。

## 11. 手动启动验收流程

先手动启动服务：

```powershell
cd D:\Projects\claude-workspace\claude-relay-service
node src\app.js
```

另开 PowerShell 启动 frpc：

```powershell
D:\Projects\claude-workspace\frp_0.68.1_windows_amd64\frpc.exe -c D:\Projects\claude-workspace\frp_0.68.1_windows_amd64\frpc.toml
```

本地验收：

```powershell
curl.exe -i http://127.0.0.1:3001/health --max-time 10
curl.exe -L -o NUL -w "%{http_code}`n" http://127.0.0.1:3001/admin-next/ --max-time 10
docker exec claude-redis redis-cli ping
```

只有本地验收通过，才进入 NSSM 服务化。

## 12. NSSM 服务化流程

必须使用管理员 PowerShell。

安装服务：

```powershell
powershell -ExecutionPolicy Bypass -File D:\Projects\ops\claude-relay\install-nssm.ps1
```

目标服务：

```text
claude-relay-service
frpc
```

目标启动链路：

```text
NSSM -> D:\Projects\ops\claude-relay\run-service.ps1 -> node src\app.js
NSSM -> D:\Projects\ops\claude-relay\run-frpc.ps1 -> frpc.exe -c frpc.toml
```

验证：

```powershell
Get-Service claude-relay-service,frpc
curl.exe -i http://127.0.0.1:3001/health --max-time 10
```

预期：

```text
claude-relay-service Running
frpc Running
health 正常
```

如果机器曾经半安装过服务，先确认旧服务：

```powershell
Get-Service claude-relay-service,frpc -ErrorAction SilentlyContinue
```

如需清理旧服务：

```powershell
sc.exe delete claude-relay-service
sc.exe delete frpc
```

## 13. 飞书通知验收流程

NSSM 通过 wrapper 启动后，应收到：

```text
Claude Relay Service 启动
frpc 隧道启动
```

查看日志：

```powershell
Get-Content D:\Projects\claude-workspace\claude-relay-service\logs\service-task.out.log -Tail 80
Get-Content D:\Projects\claude-workspace\claude-relay-service\logs\service-task.err.log -Tail 80
Get-Content D:\Projects\claude-workspace\claude-relay-service\logs\frpc-task.out.log -Tail 80
Get-Content D:\Projects\claude-workspace\claude-relay-service\logs\frpc-task.err.log -Tail 80
```

飞书不通时检查：

```text
D:\Projects\ops\claude-relay\feishu-config.ps1
D:\Projects\ops\claude-relay\send-feishu.ps1
网络连通性
webhook 是否过期
secret 是否正确
```

## 14. 60 机器交接流程

Windows 节点部署人只提供信息，不直接操作 60 机器。

交给 60 机器运维：

```text
机器编号:
公网域名: apiX.yumiai.art
frpc name: yumiai-X
remotePort: 1300X
Caddy reverse_proxy: 127.0.0.1:<remotePort>
本机 health: http://127.0.0.1:3001/health 已正常
```

60 机器侧要确认：

```text
DNS 指向正确
Caddy 配置正确
Caddy reload 成功
frps 正常
remotePort 只给本机回环使用
公网 443 正常
```

公网验收：

```powershell
curl.exe -i https://apiX.yumiai.art/health --max-time 20
```

如果本地 health 正常但公网不通，优先排查 60 机器 Caddy/DNS/443/frps，不要在 Windows 节点上反复改服务。

## 15. 总调度接管流程

公网验收通过后，登记到总调度机器。

总调度应保存：

```text
机器编号
公网域名
health URL
后台 URL
frpc name
remotePort
节点状态
权重/优先级
是否允许接流量
最近验收时间
最近失败原因
负责人
```

接管动作：

```text
1. 添加节点登记
2. 添加 health 检查
3. 添加飞书/告警映射
4. 标记节点为 standby 或 active
5. 小流量验证
6. 正式纳入调度
```

总调度健康检查建议：

```text
GET https://apiX.yumiai.art/health
超时: 10-20 秒
连续失败阈值: 3 次
恢复阈值: 连续成功 2 次
失败动作: 摘除节点并告警
恢复动作: 标记可用，人工确认后接回
```

## 16. 私密库备份流程

新节点验收后，把敏感配置备份到私密库。

建议目录：

```text
D:\secrets-backup\NX
  README.md
  config-backup\.env
  config-backup\init.json
  config-backup\frpc.toml
  ops\feishu-config.ps1
  ops\run-service.ps1
  ops\run-frpc.ps1
  ops\install-nssm.ps1
```

敏感文件：

```text
D:\Projects\claude-workspace\claude-relay-service\.env
D:\Projects\claude-workspace\claude-relay-service\data\init.json
D:\Projects\claude-workspace\frp_0.68.1_windows_amd64\frpc.toml
D:\Projects\ops\claude-relay\feishu-config.ps1
D:\redis-data
```

原则：

1. 私密库可以保存敏感配置。
2. 公开仓库不能保存敏感配置。
3. 新机器普通上线不复制旧机器 `.env` 和 `init.json`。
4. 迁移旧实例时才复制旧机器 `.env`、`init.json`、Redis dump。

## 17. 日常运维流程

查看服务：

```powershell
Get-Service claude-relay-service,frpc
```

重启服务：

```powershell
Restart-Service claude-relay-service
Restart-Service frpc
```

查看进程：

```powershell
Get-CimInstance Win32_Process -Filter "name='node.exe' or name='frpc.exe'" |
  Select-Object ProcessId,Name,CommandLine
```

查看本地服务：

```powershell
curl.exe -i http://127.0.0.1:3001/health --max-time 10
curl.exe -L -o NUL -w "%{http_code}`n" http://127.0.0.1:3001/admin-next/ --max-time 10
```

查看 Redis：

```powershell
docker ps --filter "name=claude-redis"
docker exec claude-redis redis-cli ping
docker exec claude-redis redis-cli dbsize
```

查看日志：

```powershell
Get-Content D:\Projects\claude-workspace\claude-relay-service\logs\service-task.out.log -Tail 100
Get-Content D:\Projects\claude-workspace\claude-relay-service\logs\service-task.err.log -Tail 100
Get-Content D:\Projects\claude-workspace\claude-relay-service\logs\frpc-task.out.log -Tail 100
Get-Content D:\Projects\claude-workspace\claude-relay-service\logs\frpc-task.err.log -Tail 100
```

## 18. 代码更新流程

更新前：

```powershell
cd D:\Projects\claude-workspace
git status --short
git rev-parse HEAD
```

停止接流量：

```text
总调度机器把当前节点标记为 standby 或摘除
确认没有新流量进入
```

更新代码：

```powershell
cd D:\Projects\claude-workspace
git pull --ff-only
cd D:\Projects\claude-workspace\claude-relay-service
npm.cmd install
cd web\admin-spa
npm.cmd install
npm.cmd run build
cd ..\..
```

重启：

```powershell
Restart-Service claude-relay-service
Restart-Service frpc
```

验收：

```powershell
curl.exe -i http://127.0.0.1:3001/health --max-time 10
curl.exe -i https://apiX.yumiai.art/health --max-time 20
```

通过后：

```text
总调度机器恢复节点接流量
记录更新时间、commit、验证结果
```

## 19. Redis 备份和恢复流程

手动触发 Redis 保存：

```powershell
docker exec claude-redis redis-cli save
```

备份 dump：

```powershell
Copy-Item D:\redis-data\dump.rdb D:\redis-backup\dump-YYYYMMDD-HHMMSS.rdb
```

恢复原则：

1. 普通新机器不要恢复旧 Redis。
2. 只有做旧实例迁移或灾难恢复时才恢复 Redis。
3. 恢复前停止服务和 Redis 容器。
4. 恢复后验证 Redis key 数和服务 health。

恢复步骤概要：

```text
1. 摘除节点流量
2. Stop-Service claude-relay-service
3. docker stop claude-redis
4. 替换 D:\redis-data\dump.rdb
5. docker start claude-redis
6. Start-Service claude-relay-service
7. 验证 Redis 和 health
8. 总调度恢复接管
```

## 20. 整机迁移流程

迁移旧机器到新机器时，和普通新机上线不同。

需要迁移：

```text
.env
data\init.json
frpc.toml
Redis dump
飞书配置
ops wrapper
机器登记信息
```

迁移流程：

```text
1. 总调度摘除旧节点
2. 旧机器备份 .env/init.json/frpc.toml/Redis/ops
3. 新机器安装基础环境
4. 新机器拉代码和安装依赖
5. 新机器恢复旧配置和 Redis
6. 新机器使用旧 frpc name/remotePort，或按迁移方案切换新编号
7. 本地验证
8. frpc 验证
9. 公网验证
10. 总调度接回
11. 旧机器停服务或下线
```

注意：

1. 如果保留旧域名和 `remotePort`，旧机器必须先停止 frpc。
2. 不能让两台机器同时使用同一个 frpc `name`。
3. 迁移期间要有明确回滚点。

## 21. 节点下线流程

下线前：

```text
1. 总调度摘除节点
2. 确认无流量
3. 备份敏感配置和 Redis
4. 通知 60 机器运维移除或保留 Caddy 配置
```

停止服务：

```powershell
Stop-Service claude-relay-service
Stop-Service frpc
docker stop claude-redis
```

可选删除服务：

```powershell
sc.exe delete claude-relay-service
sc.exe delete frpc
```

记录：

```text
下线时间
下线原因
备份位置
是否释放 remotePort
是否释放域名
负责人
```

## 22. 故障分流流程

先判断故障在哪一层。

### 本地服务不通

检查：

```powershell
Get-Service claude-relay-service
Get-Content D:\Projects\claude-workspace\claude-relay-service\logs\service-task.err.log -Tail 100
docker exec claude-redis redis-cli ping
```

优先处理：

```text
Node 服务崩溃
.env 错误
Redis 不通
端口 3001 被占用
依赖缺失
```

### 本地 health 正常，公网不通

Windows 节点大概率正常，检查：

```text
frpc 是否连接成功
60 机器 frps
60 机器 Caddy
DNS
443
Caddy reverse_proxy 端口
```

### frpc 不通

检查：

```powershell
Get-Service frpc
Get-Content D:\Projects\claude-workspace\claude-relay-service\logs\frpc-task.err.log -Tail 100
Get-Content D:\Projects\claude-workspace\claude-relay-service\logs\frpc-task.out.log -Tail 100
```

常见原因：

```text
token 错误
name 冲突
remotePort 冲突
60 机器 frps 不通
本机网络不通
```

### 飞书不通知

检查：

```text
feishu-config.ps1
send-feishu.ps1
wrapper 是否真正由 NSSM 启动
网络访问飞书 webhook 是否正常
```

## 23. 最终验收清单

上线前逐项确认：

```text
[ ] 机器编号已分配
[ ] remotePort 已分配且唯一
[ ] 公网域名已分配
[ ] Git 可用
[ ] Node.js 可用
[ ] npm.cmd 可用
[ ] Docker Desktop 可用
[ ] claude-workspace 已拉取
[ ] claude-relay-service 依赖已安装
[ ] admin-spa 已构建
[ ] .env 已独立生成
[ ] data\init.json 已独立生成
[ ] Redis 使用 Docker Redis 7.2
[ ] Redis PING 返回 PONG
[ ] frpc.toml 已按机器编号修改
[ ] frpc name 唯一
[ ] remotePort 唯一
[ ] 本地 health 正常
[ ] admin-next 可访问
[ ] NSSM 服务已安装
[ ] claude-relay-service Running
[ ] frpc Running
[ ] 飞书启动通知正常
[ ] 60 机器公网验收通过
[ ] 总调度登记信息已提交
[ ] 私密库备份完成
[ ] 未把 .env/init.json/token/webhook 放进公开仓库
```

## 24. 禁止事项

禁止：

```text
把 .env 提交到公开仓库
把 data\init.json 提交到公开仓库
把 frpc token 写进公开文档
把飞书 webhook/secret 写进公开仓库
直接开放 remotePort 到公网
新机器直接复用 N3 的 .env/init.json
两台机器同时使用同一个 frpc name
没有本地验收就安装 NSSM
没有摘流量就更新生产节点
没有备份就做迁移或下线
```

## 25. 快速命令汇总

环境检查：

```powershell
node -v
npm.cmd -v
git --version
docker --version
docker ps
```

服务检查：

```powershell
Get-Service claude-relay-service,frpc
curl.exe -i http://127.0.0.1:3001/health --max-time 10
docker exec claude-redis redis-cli ping
```

重启：

```powershell
Restart-Service claude-relay-service
Restart-Service frpc
```

日志：

```powershell
Get-Content D:\Projects\claude-workspace\claude-relay-service\logs\service-task.out.log -Tail 100
Get-Content D:\Projects\claude-workspace\claude-relay-service\logs\service-task.err.log -Tail 100
Get-Content D:\Projects\claude-workspace\claude-relay-service\logs\frpc-task.out.log -Tail 100
Get-Content D:\Projects\claude-workspace\claude-relay-service\logs\frpc-task.err.log -Tail 100
```

公网验收：

```powershell
curl.exe -i https://apiX.yumiai.art/health --max-time 20
```

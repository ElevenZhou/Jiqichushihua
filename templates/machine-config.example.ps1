# Copy this file to machine-config.ps1 for a real machine if values differ.
# Do not commit machine-config.ps1 if it contains private repository URLs or secrets.

$MachineNo = 4

$WorkspaceRoot = "D:\Projects"
$SecretsRoot = "D:\secrets-backup"
$RedisDataDir = "D:\redis-data"
$RedisBackupDir = "D:\redis-backup"

$ClaudeWorkspaceRepo = "https://github.com/ElevenZhou/claude-workspace.git"
$ClaudeWorkspacePath = "D:\Projects\claude-workspace"
$ClaudeRelayServicePath = "D:\Projects\claude-workspace\claude-relay-service"

# Set this to the real private repo URL on machines that should clone secrets.
# Example: git@github.com:ORG/secrets-backup.git
$SecretsBackupRepo = ""

$OpsPath = "D:\Projects\ops\claude-relay"
$FrpDir = "D:\Projects\claude-workspace\frp_0.68.1_windows_amd64"

$LocalServicePort = 3001
$RedisPort = 6380
$FrpcName = "yumiai-$MachineNo"
$RemotePort = 12999 + $MachineNo
$PublicDomain = "api$MachineNo.yumiai.art"


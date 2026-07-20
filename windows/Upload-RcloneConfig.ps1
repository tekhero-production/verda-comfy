param(
    [Parameter(Mandatory=$true)]
    [string]$InstanceIP,

    [Parameter(Mandatory=$true)]
    [string]$RcloneConfigPath,

    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_ed25519"
)

if (-not (Test-Path -LiteralPath $KeyPath)) {
    throw "SSH private key not found: $KeyPath"
}

if (-not (Test-Path -LiteralPath $RcloneConfigPath)) {
    throw "rclone.conf not found: $RcloneConfigPath"
}

ssh -i $KeyPath "root@$InstanceIP" "mkdir -p /root/.config/rclone && chmod 700 /root/.config/rclone"
scp -i $KeyPath $RcloneConfigPath "root@${InstanceIP}:/root/.config/rclone/rclone.conf"
ssh -i $KeyPath "root@$InstanceIP" "chmod 600 /root/.config/rclone/rclone.conf && rclone lsd gdrive:"

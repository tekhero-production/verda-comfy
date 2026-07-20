param(
    [Parameter(Mandatory=$true)]
    [string]$InstanceIP,

    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_ed25519"
)

if (-not (Test-Path -LiteralPath $KeyPath)) {
    throw "SSH private key not found: $KeyPath"
}

Write-Host "Opening the SSH session and ComfyUI tunnel..."
Write-Host "Keep this window open, then browse to http://127.0.0.1:8188"

ssh -i $KeyPath -L 8188:127.0.0.1:8188 "root@$InstanceIP"

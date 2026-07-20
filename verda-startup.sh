#!/bin/bash
set -Eeuo pipefail

# EDIT THIS before adding the script in Verda.
COMFY_IMAGE="ghcr.io/REPLACE_WITH_LOWERCASE_GITHUB_USERNAME/verda-comfy:latest"

exec > >(tee -a /var/log/verda-comfy-bootstrap.log) 2>&1
echo "[$(date -Is)] Starting Verda Comfy bootstrap"

export DEBIAN_FRONTEND=noninteractive

for _ in $(seq 1 60); do
  if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl python3 python3-venv rclone

if ! command -v docker >/dev/null 2>&1; then
  apt-get install -y docker.io
fi

systemctl enable --now docker

python3 -m venv /opt/hf
/opt/hf/bin/python -m pip install --upgrade pip
/opt/hf/bin/python -m pip install --upgrade huggingface_hub

mkdir -p \
  /srv/comfy/models/diffusion_models \
  /srv/comfy/models/text_encoders \
  /srv/comfy/models/vae \
  /srv/comfy/models/loras \
  /srv/comfy/input \
  /srv/comfy/output \
  /srv/comfy/user \
  /srv/comfy/workflows \
  /srv/comfy/datasets \
  /srv/comfy/training \
  /srv/comfy/logs \
  /root/.config/rclone

cat >/etc/verda-comfy.env <<ENVEOF
COMFY_IMAGE=${COMFY_IMAGE}
GDRIVE_REMOTE=gdrive
GDRIVE_ROOT=Verda-Comfy
ENVEOF
chmod 600 /etc/verda-comfy.env

echo "Pulling prepared ComfyUI image: ${COMFY_IMAGE}"
docker pull "${COMFY_IMAGE}"

cat >/usr/local/bin/start-comfy-session <<'START_SCRIPT'
#!/bin/bash
set -Eeuo pipefail
source /etc/verda-comfy.env

WITH_TRAINING=0
if [[ "${1:-}" == "--with-training" ]]; then
  WITH_TRAINING=1
fi

mkdir -p \
  /srv/comfy/models/diffusion_models \
  /srv/comfy/models/text_encoders \
  /srv/comfy/models/vae \
  /srv/comfy/models/loras \
  /srv/comfy/input /srv/comfy/output /srv/comfy/user \
  /srv/comfy/workflows /srv/comfy/datasets /srv/comfy/training \
  /srv/comfy/logs

MAIN_MODEL="/srv/comfy/models/diffusion_models/flux-2-klein-base-9b.safetensors"
QWEN_MODEL="/srv/comfy/models/text_encoders/qwen_3_8b.safetensors"
VAE_MODEL="/srv/comfy/models/vae/flux2-vae.safetensors"

HF_TOKEN_VALUE=""
if [[ ! -s "$MAIN_MODEL" ]]; then
  read -rsp "Paste your Hugging Face READ token (input is hidden): " HF_TOKEN_VALUE
  echo
  if [[ -z "$HF_TOKEN_VALUE" ]]; then
    echo "A Hugging Face token is required for the gated FLUX Base repository."
    exit 1
  fi
fi

declare -a PIDS=()
declare -a NAMES=()

if [[ ! -s "$MAIN_MODEL" ]]; then
  (
    export HF_TOKEN="$HF_TOKEN_VALUE"
    /opt/hf/bin/hf download \
      black-forest-labs/FLUX.2-klein-base-9B \
      flux-2-klein-base-9b.safetensors \
      --local-dir /srv/comfy/models/diffusion_models
  ) > /srv/comfy/logs/download-flux.log 2>&1 &
  PIDS+=("$!")
  NAMES+=("FLUX Base 9B")
fi

if [[ ! -s "$QWEN_MODEL" ]]; then
  (
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT
    /opt/hf/bin/hf download \
      Comfy-Org/vae-text-encorder-for-flux-klein-9b \
      split_files/text_encoders/qwen_3_8b.safetensors \
      --local-dir "$TMP_DIR"
    install -m 0644 \
      "$TMP_DIR/split_files/text_encoders/qwen_3_8b.safetensors" \
      "$QWEN_MODEL"
  ) > /srv/comfy/logs/download-qwen.log 2>&1 &
  PIDS+=("$!")
  NAMES+=("Qwen 3 8B")
fi

if [[ ! -s "$VAE_MODEL" ]]; then
  (
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT
    /opt/hf/bin/hf download \
      Comfy-Org/vae-text-encorder-for-flux-klein-9b \
      split_files/vae/flux2-vae.safetensors \
      --local-dir "$TMP_DIR"
    install -m 0644 \
      "$TMP_DIR/split_files/vae/flux2-vae.safetensors" \
      "$VAE_MODEL"
  ) > /srv/comfy/logs/download-vae.log 2>&1 &
  PIDS+=("$!")
  NAMES+=("FLUX 2 VAE")
fi

if [[ -s /root/.config/rclone/rclone.conf ]]; then
  (
    set -e
    copy_from_drive() {
      local remote_sub="$1"
      local local_path="$2"
      local remote_path="${GDRIVE_REMOTE}:${GDRIVE_ROOT}/${remote_sub}"
      mkdir -p "$local_path"
      if rclone lsf "$remote_path" >/dev/null 2>&1; then
        rclone copy \
          "$remote_path" \
          "$local_path" \
          --fast-list --transfers 8 --checkers 16
      else
        echo "Remote folder not present yet; skipping: $remote_path"
      fi
    }

    copy_from_drive input /srv/comfy/input
    copy_from_drive user /srv/comfy/user
    copy_from_drive workflows /srv/comfy/workflows
    copy_from_drive loras /srv/comfy/models/loras

    if [[ "$WITH_TRAINING" -eq 1 ]]; then
      copy_from_drive datasets /srv/comfy/datasets
      copy_from_drive training /srv/comfy/training
    fi
  ) > /srv/comfy/logs/restore-drive.log 2>&1 &
  PIDS+=("$!")
  NAMES+=("Google Drive restore")
else
  echo "No rclone config found. Drive restore is being skipped."
fi

FAIL=0
for i in "${!PIDS[@]}"; do
  echo "Waiting for ${NAMES[$i]}..."
  if ! wait "${PIDS[$i]}"; then
    echo "FAILED: ${NAMES[$i]}. Check /srv/comfy/logs/"
    FAIL=1
  fi
done
unset HF_TOKEN_VALUE

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi

for required in "$MAIN_MODEL" "$QWEN_MODEL" "$VAE_MODEL"; do
  if [[ ! -s "$required" ]]; then
    echo "Missing required file: $required"
    exit 1
  fi
done

docker rm -f comfyui >/dev/null 2>&1 || true

docker run -d \
  --name comfyui \
  --restart unless-stopped \
  --gpus all \
  --ipc=host \
  --shm-size=16g \
  -p 127.0.0.1:8188:8188 \
  -v /srv/comfy/models:/opt/ComfyUI/models \
  -v /srv/comfy/input:/opt/ComfyUI/input \
  -v /srv/comfy/output:/opt/ComfyUI/output \
  -v /srv/comfy/user:/opt/ComfyUI/user \
  -v /srv/comfy/workflows:/workflows \
  -v /srv/comfy/datasets:/datasets \
  -v /srv/comfy/training:/training \
  "$COMFY_IMAGE"

echo "Waiting for ComfyUI..."
for _ in $(seq 1 120); do
  if curl -fsS http://127.0.0.1:8188/system_stats >/dev/null 2>&1; then
    echo "ComfyUI is ready at http://127.0.0.1:8188"
    echo "Container logs: docker logs -f comfyui"
    exit 0
  fi
  sleep 2
done

echo "ComfyUI did not become ready in time."
docker logs --tail 200 comfyui || true
exit 1
START_SCRIPT

cat >/usr/local/bin/backup-comfy <<'BACKUP_SCRIPT'
#!/bin/bash
set -Eeuo pipefail
source /etc/verda-comfy.env

VERIFY=0
if [[ "${1:-}" == "--verify" ]]; then
  VERIFY=1
fi

if [[ ! -s /root/.config/rclone/rclone.conf ]]; then
  echo "Missing /root/.config/rclone/rclone.conf"
  exit 1
fi

copy_to_drive() {
  local local_path="$1"
  local remote_sub="$2"

  if [[ -e "$local_path" ]]; then
    echo "Backing up $local_path -> ${GDRIVE_REMOTE}:${GDRIVE_ROOT}/${remote_sub}"
    rclone copy \
      "$local_path" \
      "${GDRIVE_REMOTE}:${GDRIVE_ROOT}/${remote_sub}" \
      --fast-list --transfers 8 --checkers 16 --progress

    if [[ "$VERIFY" -eq 1 ]]; then
      echo "Verifying $remote_sub"
      rclone check \
        "$local_path" \
        "${GDRIVE_REMOTE}:${GDRIVE_ROOT}/${remote_sub}" \
        --one-way --checkers 16
    fi
  fi
}

copy_to_drive /srv/comfy/output output
copy_to_drive /srv/comfy/input input
copy_to_drive /srv/comfy/user user
copy_to_drive /srv/comfy/workflows workflows
copy_to_drive /srv/comfy/models/loras loras
copy_to_drive /srv/comfy/datasets datasets
copy_to_drive /srv/comfy/training training

{
  echo "Backup completed: $(date -Is)"
  echo "Host: $(hostname)"
  echo
  find /srv/comfy/output /srv/comfy/user /srv/comfy/workflows \
       /srv/comfy/models/loras /srv/comfy/datasets /srv/comfy/training \
       -type f -printf '%s %TY-%Tm-%TdT%TH:%TM:%TS %p\n' 2>/dev/null | sort
} >/tmp/verda-comfy-backup-manifest.txt

rclone copyto \
  /tmp/verda-comfy-backup-manifest.txt \
  "${GDRIVE_REMOTE}:${GDRIVE_ROOT}/manifests/last-backup.txt"

date -Is >/root/SAFE_TO_DELETE
echo
echo "BACKUP FINISHED SUCCESSFULLY."
echo "Marker created: /root/SAFE_TO_DELETE"
echo "You may now delete the instance and select its OS storage for deletion."
BACKUP_SCRIPT

cat >/usr/local/bin/status-comfy <<'STATUS_SCRIPT'
#!/bin/bash
set -u
echo "=== Docker container ==="
docker ps -a --filter name='^/comfyui$'
echo
echo "=== Required files ==="
ls -lh \
  /srv/comfy/models/diffusion_models/flux-2-klein-base-9b.safetensors \
  /srv/comfy/models/text_encoders/qwen_3_8b.safetensors \
  /srv/comfy/models/vae/flux2-vae.safetensors 2>/dev/null || true
echo
echo "=== Disk usage ==="
df -h /
du -sh /srv/comfy 2>/dev/null || true
echo
echo "=== Recent logs ==="
docker logs --tail 30 comfyui 2>/dev/null || true
STATUS_SCRIPT

cat >/usr/local/bin/queue-workflow <<'QUEUE_SCRIPT'
#!/usr/bin/env python3
import json
import sys
import urllib.error
import urllib.request

if len(sys.argv) != 2:
    raise SystemExit("Usage: queue-workflow /srv/comfy/workflows/workflow_api.json")

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    prompt = json.load(handle)

payload = json.dumps({"prompt": prompt}).encode("utf-8")
request = urllib.request.Request(
    "http://127.0.0.1:8188/prompt",
    data=payload,
    headers={"Content-Type": "application/json"},
    method="POST",
)

try:
    with urllib.request.urlopen(request, timeout=60) as response:
        print(response.read().decode("utf-8"))
except urllib.error.HTTPError as error:
    body = error.read().decode("utf-8", errors="replace")
    print(body, file=sys.stderr)
    raise
QUEUE_SCRIPT

chmod 755 \
  /usr/local/bin/start-comfy-session \
  /usr/local/bin/backup-comfy \
  /usr/local/bin/status-comfy \
  /usr/local/bin/queue-workflow

cat >/root/START_HERE.txt <<'HELPEOF'
Bootstrap finished.

1. Upload rclone.conf to:
   /root/.config/rclone/rclone.conf

2. Run:
   start-comfy-session

For datasets/training restore:
   start-comfy-session --with-training

Status:
   status-comfy

Before deleting:
   backup-comfy --verify
HELPEOF

echo "[$(date -Is)] Bootstrap finished"
touch /root/VERDA_COMFY_BOOTSTRAP_DONE

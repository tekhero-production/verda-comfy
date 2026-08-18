# RTX PRO 6000 Blackwell setup for Verda

This project builds a dedicated ComfyUI image for the NVIDIA RTX PRO 6000
Blackwell Server Edition on Verda.

The image is intentionally separate from the previous `:latest` image:

```text
ghcr.io/tekhero-production/verda-comfy:blackwell-cu128-2026-08-18
```

The existing `:latest` tag is not overwritten, so it remains available as the
legacy A6000/A100 fallback.

## What this configuration contains

- PyTorch 2.10.0
- CUDA 12.8
- cuDNN 9
- ComfyUI and the three required custom-node repositories pinned to commits
  recorded on 2026-08-18
- the existing FLUX.2 Klein Base 9B, Qwen 3 8B, VAE, Google Drive restore,
  backup, SSH tunnel, and workflow helpers
- a startup-time test that requires CUDA 12.8 and compute capability 12.0

Do not change the model filenames or workflow JSON files for the first test.
This upgrade changes the GPU software layer only.

## Phase 1: publish the Blackwell image on GitHub

Do all of this before starting a billable Verda instance.

### 1. Open PowerShell in this folder

If the folder is still on the Desktop:

```powershell
Set-Location "C:\Users\hassa\Desktop\verda-comfy-rtxpro6000-cu128"
```

Confirm that this is the correct repository:

```powershell
git remote -v
git log -1 --oneline
git status --short
```

Expected remote:

```text
https://github.com/tekhero-production/verda-comfy.git
```

Expected modified/new files:

```text
M  .github/workflows/publish-image.yml
M  Dockerfile
M  README.md
M  verda-startup.sh
?? .gitattributes
?? RTX-PRO-6000-SETUP.md
```

### 2. Review and validate the changes

```powershell
git diff --check
git diff -- Dockerfile .github/workflows/publish-image.yml verda-startup.sh README.md
```

`git diff --check` should print nothing.

### 3. Create a branch and push it

```powershell
git switch -c codex/rtx-pro-6000-cu128
git add .gitattributes Dockerfile .github/workflows/publish-image.yml verda-startup.sh README.md RTX-PRO-6000-SETUP.md
git commit -m "Add RTX PRO 6000 CUDA 12.8 image"
git push -u origin codex/rtx-pro-6000-cu128
```

If Git asks you to authenticate, complete the normal GitHub browser sign-in.
Never paste the Hugging Face token, `rclone.conf`, Google token, or SSH private
key into Git or GitHub.

### 4. Merge the pull request

1. Open `https://github.com/tekhero-production/verda-comfy`.
2. Open the pull request offered for `codex/rtx-pro-6000-cu128`.
3. Confirm that only the six files above are included.
4. Merge the pull request into `main`.

The merge triggers **Build and publish ComfyUI Blackwell image** automatically.

### 5. Wait for the image build

1. Open the repository's **Actions** tab.
2. Open **Build and publish ComfyUI Blackwell image**.
3. Wait for the build job to finish with a green check.
4. If it fails, do not create the Verda instance. Open the failed step and fix
   the first real error before retrying.

The workflow publishes both tags:

```text
ghcr.io/tekhero-production/verda-comfy:blackwell-cu128
ghcr.io/tekhero-production/verda-comfy:blackwell-cu128-2026-08-18
```

The Verda script uses the dated tag so a later image rebuild cannot silently
change a working setup.

### 6. Confirm that GHCR is public

1. Open the `tekhero-production` organization on GitHub.
2. Open **Packages** and select `verda-comfy`.
3. Confirm that `blackwell-cu128-2026-08-18` is listed.
4. In **Package settings**, confirm the package is public.

The startup script pulls anonymously. If the package is private, `docker pull`
will fail because the script deliberately contains no GitHub credentials.

## Phase 2: add the startup script to Verda

### 7. Create a separate saved startup script

Do not overwrite the known-working legacy script yet.

1. Open the Verda console.
2. Go to the startup-script area or begin deploying an instance and choose to
   create a startup script.
3. Name it `ComfyUI RTX PRO 6000 Blackwell CUDA 12.8`.
4. Open `verda-startup.sh` from this project in a text editor.
5. Copy the entire file, beginning with `#!/bin/bash`.
6. Paste it into Verda and save it.

Confirm that the top of the saved script contains exactly:

```bash
COMFY_IMAGE="ghcr.io/tekhero-production/verda-comfy:blackwell-cu128-2026-08-18"
```

Do not add any secrets to the script.

## Phase 3: deploy the RTX PRO 6000 instance

### 8. Run the cost preflight

Before deploying, confirm:

- there is no other running or shut-down GPU instance;
- no unwanted paid block volume is retained;
- the SSH private key is available locally;
- `rclone.conf` is available locally;
- the Hugging Face Read token is available;
- important outputs from the previous session are backed up.

### 9. Configure the instance

In Verda, choose:

- **On-demand GPU instance**
- **1x RTX PRO 6000 96GB**
- an Ubuntu image that explicitly includes **CUDA and Docker**
- preferably Ubuntu 24.04 with CUDA 12.8 or newer
- **120 GiB** disposable OS storage for generation/testing
- more storage if training datasets and checkpoints require it
- the existing SSH public key
- startup script: **ComfyUI RTX PRO 6000 Blackwell CUDA 12.8**

Do not attach the previous paid block volume unless it contains data you have
deliberately decided to retain.

Deploy the instance and copy its public IP address.

## Phase 4: bootstrap and start ComfyUI

### 10. Open the SSH tunnel

From this project folder on Windows:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\windows\Connect-Comfy.ps1 -InstanceIP "INSTANCE_IP"
```

Keep that PowerShell/SSH window open for the entire ComfyUI session.

### 11. Watch the bootstrap

Inside the SSH session:

```bash
tail -f /var/log/verda-comfy-bootstrap.log
```

The script will:

1. install the required host tools;
2. pull the dated Blackwell image;
3. display the GPU name, driver, and memory;
4. start a temporary container test;
5. require PyTorch CUDA 12.8 and compute capability `(12, 0)`;
6. create the normal ComfyUI helper commands.

Wait for:

```text
Bootstrap finished
```

Press `Ctrl+C` to stop following the log, then verify:

```bash
ls -l /root/VERDA_COMFY_BOOTSTRAP_DONE
nvidia-smi
```

If the marker does not exist, do not continue. Inspect:

```bash
tail -n 250 /var/log/verda-comfy-bootstrap.log
systemctl status docker --no-pager
```

### 12. Upload the private rclone configuration

Open a second PowerShell window on Windows; leave the SSH tunnel open.

```powershell
Set-Location "C:\Users\hassa\Desktop\verda-comfy-rtxpro6000-cu128"
Set-ExecutionPolicy -Scope Process Bypass
.\windows\Upload-RcloneConfig.ps1 `
  -InstanceIP "INSTANCE_IP" `
  -RcloneConfigPath "C:\Users\hassa\AppData\Roaming\rclone\rclone.conf"
```

The helper uploads the file privately to:

```text
/root/.config/rclone/rclone.conf
```

### 13. Start the session

Return to the SSH terminal.

For image generation:

```bash
start-comfy-session
```

For a training session that also restores datasets and training files:

```bash
start-comfy-session --with-training
```

When prompted, paste the Hugging Face **Read** token. Input is hidden.

Wait for:

```text
ComfyUI is ready at http://127.0.0.1:8188
```

### 14. Verify the exact GPU stack

```bash
docker exec comfyui python -c "import torch; print('torch:', torch.__version__); print('CUDA:', torch.version.cuda); print('GPU:', torch.cuda.get_device_name(0)); print('capability:', torch.cuda.get_device_capability(0)); print('available:', torch.cuda.is_available())"
```

Expected essentials:

```text
CUDA: 12.8
GPU: NVIDIA RTX PRO 6000 Blackwell Server Edition
capability: (12, 0)
available: True
```

Also run:

```bash
status-comfy
docker exec comfyui nvidia-smi
```

## Phase 5: test the real workflow

### 15. Generate one test image

1. Open `http://127.0.0.1:8188` on the Windows computer.
2. Load the existing FLUX.2 Klein Base 9B workflow.
3. Confirm the expected model selectors:
   - `flux-2-klein-base-9b.safetensors`
   - `qwen_3_8b.safetensors`
   - `flux2-vae.safetensors`
4. Generate one image with the existing settings.

Monitor the GPU in the SSH terminal if desired:

```bash
watch -n 1 nvidia-smi
```

Success means:

- no missing-node errors;
- no CUDA or unsupported-architecture error;
- the workflow finishes;
- the image appears in ComfyUI and `/srv/comfy/output`.

Do not switch to FP8/NVFP4 models during this first validation. That is a
separate optimization and would change model files and workflow selectors.

## Phase 6: back up and stop billing

### 16. Back up and verify

Before deleting anything:

```bash
backup-comfy --verify
ls -l /root/SAFE_TO_DELETE
rclone cat gdrive:Verda-Comfy/manifests/last-backup.txt | head -30
```

Only continue after `backup-comfy --verify` succeeds and the marker exists.

### 17. Delete compute and disposable storage

In Verda:

1. Delete the GPU instance.
2. Select its disposable OS volume for deletion.
3. Confirm there is no shut-down instance still billed.
4. Confirm no unintended volume remains.

## Rollback

If the Blackwell image or workflow fails:

1. preserve the bootstrap and Docker error messages;
2. back up any unique output if a session was started;
3. delete the RTX PRO instance and its disposable OS volume;
4. leave the GHCR `:latest` tag untouched;
5. deploy an A100 80GB using the previous startup script that references
   `ghcr.io/tekhero-production/verda-comfy:latest`.

The separate tag and separate Verda startup script make this rollback safe.

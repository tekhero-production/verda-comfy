# Verda ComfyUI disposable-instance starter

This starter implements:

- A reusable GHCR Docker image containing ComfyUI, PyTorch CUDA 12.6 and the custom nodes required by the supplied workflows.
- A Verda startup script.
- Parallel downloads for:
  - `flux-2-klein-base-9b.safetensors`
  - `qwen_3_8b.safetensors`
  - `flux2-vae.safetensors`
- Google Drive restore/backup through rclone.
- Local SSH tunneling.
- A helper for submitting ComfyUI API-format workflows.
- No Hugging Face or Google secrets embedded in the image or startup script.

## Important

The first-time preparation is not a 5-minute task. Building the Docker image and configuring Google Drive are one-time steps. The 5–15 minute target applies to later disposable Verda sessions on a fast connection. It is not guaranteed.

## Files

- `Dockerfile`: prepared ComfyUI image.
- `.github/workflows/publish-image.yml`: builds and publishes to GHCR.
- `verda-startup.sh`: paste into Verda after replacing the GitHub username.
- `windows/Connect-Comfy.ps1`: SSH plus port 8188 tunnel.
- `windows/Upload-RcloneConfig.ps1`: uploads the private rclone config.

## Security

Never place these in GitHub, GHCR, or the Verda startup script:

- Hugging Face access token.
- `rclone.conf`.
- Google OAuth tokens.
- SSH private key.

The session-start command prompts for the Hugging Face token without saving it. The rclone config must be copied privately to each temporary instance.

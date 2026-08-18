# Verda ComfyUI RTX PRO 6000 Blackwell starter

Follow **[RTX-PRO-6000-SETUP.md](RTX-PRO-6000-SETUP.md)** from the beginning.
It covers publishing the image, installing the startup script in Verda,
deployment, validation, backup, deletion, and rollback.

This starter implements:

- A dedicated GHCR Docker image containing ComfyUI, PyTorch 2.10, CUDA 12.8,
  and the custom nodes required by the supplied workflows.
- Pinned ComfyUI and custom-node commits for repeatable builds.
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

The first-time preparation is not a 5-minute task. Build and publish the image
successfully before starting a billable RTX PRO 6000 instance. The old GHCR
`:latest` tag is deliberately not overwritten; this project publishes the
separate `:blackwell-cu128` and `:blackwell-cu128-2026-08-18` tags.

## Files

- `Dockerfile`: pinned CUDA 12.8/Blackwell ComfyUI image.
- `.github/workflows/publish-image.yml`: builds and publishes the Blackwell tags to GHCR.
- `verda-startup.sh`: paste into Verda unchanged after the dated tag is published.
- `RTX-PRO-6000-SETUP.md`: complete deployment and validation guide.
- `windows/Connect-Comfy.ps1`: SSH plus port 8188 tunnel.
- `windows/Upload-RcloneConfig.ps1`: uploads the private rclone config.

## Security

Never place these in GitHub, GHCR, or the Verda startup script:

- Hugging Face access token.
- `rclone.conf`.
- Google OAuth tokens.
- SSH private key.

The session-start command prompts for the Hugging Face token without saving it. The rclone config must be copied privately to each temporary instance.

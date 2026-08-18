FROM pytorch/pytorch:2.10.0-cuda12.8-cudnn9-runtime

ARG COMFYUI_COMMIT=8b2d29176f7f1b9b72f9dff11a0848027d136910
ARG KJNODES_COMMIT=3f20054214fec9f9234fd3841ae6f1e4287948f6
ARG COMFYROLL_COMMIT=d78b780ae43fcf8c6b7c6505e6ffb4584281ceca
ARG IMAGE_SAVER_COMMIT=205d66a9d8035e3ad2ba6c61b7ebf7871664e472

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      curl \
      ca-certificates \
      ffmpeg \
      libgl1 \
      libglib2.0-0 \
      build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN git clone https://github.com/Comfy-Org/ComfyUI.git \
    && git -C ComfyUI checkout --detach "${COMFYUI_COMMIT}"

WORKDIR /opt/ComfyUI

# Keep the CUDA 12.8 PyTorch stack deterministic and Blackwell-compatible.
RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel \
    && python -m pip install --no-cache-dir \
         torch==2.10.0 \
         torchvision==0.25.0 \
         torchaudio==2.10.0 \
         --index-url https://download.pytorch.org/whl/cu128

# ComfyUI requirements also list torch/torchvision/torchaudio without pins.
# Remove only those three lines so pip cannot replace the CUDA 12.8 stack.
RUN grep -Ev '^(torch|torchvision|torchaudio)([[:space:]]|[<>=!~].*)?$' \
      requirements.txt > /tmp/comfy-requirements-no-torch.txt \
    && python -m pip install --no-cache-dir \
         -r /tmp/comfy-requirements-no-torch.txt \
    && python -m pip install --no-cache-dir \
         -r manager_requirements.txt \
    && python -m pip install --no-cache-dir --upgrade huggingface_hub \
    && rm -f /tmp/comfy-requirements-no-torch.txt

RUN git clone \
      https://github.com/kijai/ComfyUI-KJNodes.git \
      custom_nodes/ComfyUI-KJNodes \
    && git -C custom_nodes/ComfyUI-KJNodes checkout --detach "${KJNODES_COMMIT}" \
    && git clone \
      https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git \
      custom_nodes/ComfyUI_Comfyroll_CustomNodes \
    && git -C custom_nodes/ComfyUI_Comfyroll_CustomNodes checkout --detach "${COMFYROLL_COMMIT}" \
    && git clone \
      https://github.com/alexopus/ComfyUI-Image-Saver.git \
      custom_nodes/ComfyUI-Image-Saver \
    && git -C custom_nodes/ComfyUI-Image-Saver checkout --detach "${IMAGE_SAVER_COMMIT}"

RUN set -eux; \
    for folder in \
      custom_nodes/ComfyUI-KJNodes \
      custom_nodes/ComfyUI_Comfyroll_CustomNodes \
      custom_nodes/ComfyUI-Image-Saver; \
    do \
      if [ -f "$folder/requirements.txt" ]; then \
        python -m pip install --no-cache-dir \
          -r "$folder/requirements.txt"; \
      fi; \
    done

# Fail the image build immediately if the Python/CUDA stack is inconsistent.
RUN python - <<'PY'
import torch
import torchvision
import torchaudio

print("torch:", torch.__version__)
print("torchvision:", torchvision.__version__)
print("torchaudio:", torchaudio.__version__)
print("CUDA build:", torch.version.cuda)

assert torch.__version__.startswith("2.10.0")
assert torchvision.__version__.startswith("0.25.0")
assert torchaudio.__version__.startswith("2.10.0")
assert torch.version.cuda == "12.8"
PY

RUN mkdir -p \
      models/diffusion_models \
      models/text_encoders \
      models/vae \
      models/loras \
      input \
      output \
      user

EXPOSE 8188

CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188", "--enable-manager"]

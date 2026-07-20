FROM pytorch/pytorch:2.10.0-cuda12.6-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates ffmpeg libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone --depth 1 https://github.com/Comfy-Org/ComfyUI.git

WORKDIR /opt/ComfyUI
RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel \
    && python -m pip install --no-cache-dir -r requirements.txt \
    && python -m pip install --no-cache-dir -r manager_requirements.txt \
    && python -m pip install --no-cache-dir --upgrade huggingface_hub

RUN git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git \
      custom_nodes/ComfyUI-KJNodes \
    && git clone --depth 1 https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git \
      custom_nodes/ComfyUI_Comfyroll_CustomNodes \
    && git clone --depth 1 https://github.com/alexopus/ComfyUI-Image-Saver.git \
      custom_nodes/ComfyUI-Image-Saver

RUN set -eux; \
    for folder in \
      custom_nodes/ComfyUI-KJNodes \
      custom_nodes/ComfyUI_Comfyroll_CustomNodes \
      custom_nodes/ComfyUI-Image-Saver; \
    do \
      if [ -f "$folder/requirements.txt" ]; then \
        python -m pip install --no-cache-dir -r "$folder/requirements.txt"; \
      fi; \
    done

RUN mkdir -p \
      models/diffusion_models \
      models/text_encoders \
      models/vae \
      models/loras \
      input output user

EXPOSE 8188

CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188", "--enable-manager"]

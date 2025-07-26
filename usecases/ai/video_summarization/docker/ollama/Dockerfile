# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM intel/oneapi-basekit:2025.0.2-0-devel-ubuntu24.04
#FROM intel/oneapi-basekit:2025.0.1-0-devel-ubuntu22.04 AS build
ARG IPEX_LLM_VERSION=2.2.0b20250319

ARG PIP_NO_CACHE_DIR=false

# Set environment variables
ENV TZ=Asia/Shanghai PYTHONUNBUFFERED=1

WORKDIR /opt/intel/llm-app
RUN apt update \
    && apt install -y python3-venv \
        python3-pip \
        python3-apt \
        wget \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m venv .venv

RUN set -eux && \
    # Set timezone
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    # 
    # Install Python 3.11
    add-apt-repository ppa:deadsnakes/ppa -y && \
    add-apt-repository -y ppa:kobuk-team/intel-graphics && \
    apt-get install -y libze-intel-gpu1 libze1 intel-ocloc intel-opencl-icd clinfo intel-gsc intel-media-va-driver-non-free libmfx1 libmfx-gen1 libvpl2 libvpl-tools libva-glx2 va-driver-all vainfo 

RUN mkdir -p /root/.ollama \
    && mkdir -p /root/ollama_models
#    && chown -R intel /root/.ollama \
#    && chown -R intel /opt/intel/llm-app \
#    && chown -R intel /root/ollama_models
    
#USER intel
ENV PATH="/opt/intel/llm-app/.venv/bin:$PATH"
ENV LD_LIBRARY_PATH=".:$LD_LIBRARY_PATH"


RUN set -eux && \
    python3 -m pip install --upgrade pip && \
    #
    # Install Intel PyTorch extension for LLM inference
    python3 -m pip install --pre --upgrade 'ipex-llm[cpp]' --extra-index-url https://download.pytorch.org/whl/xpu && \    
    python3 -m pip install --pre --upgrade 'ipex-llm[xpu_2.6]>=2.3.0b0,<2.3.0rc1' --extra-index-url https://download.pytorch.org/whl/xpu && \
    python3 -m pip install --upgrade accelerate==0.33.0 && \
    init-ollama


HEALTHCHECK --interval=60s --timeout=5m --start-period=5s --retries=5 \
    CMD curl --fail http://localhost:11434 || exit 1

CMD ["./ollama", "serve"]

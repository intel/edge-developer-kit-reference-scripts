# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM python:3.11-slim

USER root
RUN useradd -m intel

# Install dependencies
WORKDIR /opt
RUN apt-get update && apt-get install -y \
    build-essential libsndfile1 git \
    && rm -rf /var/lib/apt/lists/*

# Install Melo TTS
RUN mkdir -p thirdparty && \
    cd thirdparty && \
    git clone https://github.com/myshell-ai/MeloTTS.git && \
    cd MeloTTS && \
    pip install -e . && \
    python -m unidic download

# Install IPEX
RUN python3 -m pip install --pre --upgrade ipex-llm[xpu] --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/ && \
    python3 -m pip install torch==2.1.0.post2 torchvision==0.16.0.post2 torchaudio==2.1.0.post2 intel-extension-for-pytorch==2.1.30.post0 oneccl_bind_pt==2.1.300+xpu --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/ && \
    python3 -m pip install setuptools==69.5.1 numpy==1.26.4 && \
    python3 -m pip install transformers==4.43.3 accelerate==0.33.0 datasets==2.20.0 peft==0.12.0 bitsandbytes==0.43.2 scipy==1.14.0 fire==0.6.0 trl==0.9.6

WORKDIR /usr/src/app
COPY requirements.txt .
RUN python3 -m pip install -r requirements.txt
COPY . .
RUN python3 nltk_download.py

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD wget --no-verbose -O /dev/null --tries=1 http://localhost:5995/healthcheck || exit 1
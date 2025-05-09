# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM openvino/ubuntu22_dev:2024.6.0

USER root

# Install dependencies
RUN apt-get update \
    && apt-get install -y wget \
        gnupg2 \
        libtbb12 \
        python3.11 \
        python3.11-venv 

# Install GPU drivers
RUN mkdir /tmp/neo \
    && cd /tmp/neo \
    && wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.17791.9/intel-igc-core_1.0.17791.9_amd64.deb \
    && wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.17791.9/intel-igc-opencl_1.0.17791.9_amd64.deb \
    && wget https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/intel-level-zero-gpu-dbgsym_1.6.31294.12_amd64.ddeb \
    && wget https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/intel-level-zero-gpu_1.6.31294.12_amd64.deb \
    && wget https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/intel-opencl-icd-dbgsym_24.39.31294.12_amd64.ddeb \
    && wget https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/intel-opencl-icd_24.39.31294.12_amd64.deb \
    && wget https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/libigdgmm12_22.5.2_amd64.deb \
    && dpkg -i *.deb

# Install NPU drivers
RUN mkdir /tmp/npu-driver \
    && cd /tmp/npu-driver\
    && wget https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-driver-compiler-npu_1.10.0.20241107-11729849322_ubuntu22.04_amd64.deb \
    && wget https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-fw-npu_1.10.0.20241107-11729849322_ubuntu22.04_amd64.deb \
    && wget https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-level-zero-npu_1.10.0.20241107-11729849322_ubuntu22.04_amd64.deb \
    && wget https://github.com/oneapi-src/level-zero/releases/download/v1.17.6/level-zero_1.17.6+u22.04_amd64.deb \
    && dpkg -i *.deb

RUN mkdir -p /usr/src \
    && chown -R openvino:openvino /usr/src \
    && mkdir -p /usr/src/app/data \
    && chown -R openvino:openvino /usr/src/app/data

USER openvino
WORKDIR /usr/src/app
RUN python3 -m venv /usr/src/.venv 
ENV PATH="/usr/src/.venv/bin:$PATH"

# Install python dependencies
RUN python3 -m pip install fastapi[all]==0.111.0 \
    sse_starlette==2.1.2 \
    scipy \
    soundfile \
    numpy==1.26.4 \
    openai==1.56.2 \
    pyyaml==6.0.1 \
    pypdf==5.0.0 \
    langchain==0.3.8 \
    langchain-chroma==0.1.4 \
    langchain-community===0.3.8 \
    chromadb==0.5.18 \
    'huggingface_hub>=0.23.0' \
    botocore==1.34.88 \
    cached_path==1.6.3
RUN python3 -m pip install --extra-index-url https://download.pytorch.org/whl/cpu \
    'torch>=2.6.0' \
    'torchaudio>=2.6.0' \
    openvino==2025.1.0 \
    optimum-intel[openvino,nncf]==1.22.0

COPY --chown=openvino:openvino backend .

EXPOSE 8011
HEALTHCHECK --interval=60s --timeout=180s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8011/healthcheck || exit 1

CMD ["python3", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8011"]

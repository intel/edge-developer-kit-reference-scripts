# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM openvino/ubuntu22_dev:2024.5.0

USER root

# Install dependencies
RUN apt-get update && apt-get install -y ffmpeg \
    wget \
    gnupg2 \
    libtbb12 \
    python3.11 \
    python3.11-venv 

# Install GPU drivers
RUN wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg \
    && echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | tee /etc/apt/sources.list.d/intel-gpu-jammy.list \
    && apt update \
    && apt-get install -y libze1 \
        intel-level-zero-gpu \
        intel-opencl-icd \
        clinfo \
    && rm -rf /var/lib/apt/lists/*

# Install NPU drivers
RUN mkdir /tmp/npu-driver \
    && cd /tmp/npu-driver\
    && wget https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-driver-compiler-npu_1.10.0.20241107-11729849322_ubuntu22.04_amd64.deb \
    && wget https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-fw-npu_1.10.0.20241107-11729849322_ubuntu22.04_amd64.deb \
    && wget https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-level-zero-npu_1.10.0.20241107-11729849322_ubuntu22.04_amd64.deb \
    && wget https://github.com/oneapi-src/level-zero/releases/download/v1.17.6/level-zero_1.17.6+u22.04_amd64.deb \
    && dpkg -i *.deb

RUN mkdir -p /usr/src \
    && chown -R openvino:openvino /usr/src

USER openvino
WORKDIR /usr/src/app
RUN python3 -m venv /usr/src/.venv 
ENV PATH="/usr/src/.venv/bin:$PATH"

# Install python dependencies
COPY --chown=openvino:openvino requirements.txt .
RUN python3 -m pip install -r requirements.txt

COPY --chown=openvino:openvino server.py .
COPY --chown=openvino:openvino utils.py .

HEALTHCHECK --interval=60s --timeout=180s --start-period=5s --retries=3 \
    CMD wget --no-verbose --no-proxy -O /dev/null --tries=1 http://stt_service:5996/healthcheck || exit 1

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM openvino/ubuntu22_dev:2024.6.0

USER root

# Install dependencies
RUN apt-get update \
    && apt-get install --no-install-recommends -y curl \
        gnupg2 \
        libtbb12 \
        python3.11 \
        python3.11-venv 

# Install GPU drivers
WORKDIR /tmp/neo
RUN curl -LO https://github.com/intel/intel-graphics-compiler/releases/download/v2.10.8/intel-igc-core-2_2.10.8+18926_amd64.deb \
    && curl -LO https://github.com/intel/intel-graphics-compiler/releases/download/v2.10.8/intel-igc-opencl-2_2.10.8+18926_amd64.deb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/25.13.33276.16/intel-level-zero-gpu-dbgsym_1.6.33276.16_amd64.ddeb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/25.13.33276.16/intel-level-zero-gpu_1.6.33276.16_amd64.deb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/25.13.33276.16/intel-opencl-icd-dbgsym_25.13.33276.16_amd64.ddeb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/25.13.33276.16/intel-opencl-icd_25.13.33276.16_amd64.deb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/25.13.33276.16/libigdgmm12_22.7.0_amd64.deb \
    && dpkg -i *.deb

# Install NPU drivers
WORKDIR /tmp/npu-driver
RUN curl -LO https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-driver-compiler-npu_1.10.0.20241107-11729849322_ubuntu22.04_amd64.deb \
    && curl -LO https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-fw-npu_1.10.0.20241107-11729849322_ubuntu22.04_amd64.deb \
    && curl -LO https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-level-zero-npu_1.10.0.20241107-11729849322_ubuntu22.04_amd64.deb \
    && curl -LO https://github.com/oneapi-src/level-zero/releases/download/v1.17.6/level-zero_1.17.6+u22.04_amd64.deb \
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
COPY --chown=openvino:openvino requirements.txt .
RUN python3 -m pip install -r requirements.txt

COPY --chown=openvino:openvino . .

HEALTHCHECK --interval=60s --timeout=180s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${SERVER_PORT:-8011}/healthcheck || exit 1

CMD ["python3", "main.py"]

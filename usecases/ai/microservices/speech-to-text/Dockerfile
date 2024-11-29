# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM openvino/ubuntu22_dev:2024.1.0

USER root
RUN useradd -m intel
WORKDIR /usr/src/app
RUN apt-get update && apt-get install -y ffmpeg wget
# Install dependencies
RUN mkdir neo && \
    cd neo && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.17791.9/intel-igc-core_1.0.17791.9_amd64.deb && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.17791.9/intel-igc-opencl_1.0.17791.9_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/intel-level-zero-gpu-dbgsym_1.6.31294.12_amd64.ddeb && \
    wget https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/intel-level-zero-gpu_1.6.31294.12_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/intel-opencl-icd-dbgsym_24.39.31294.12_amd64.ddeb && \
    wget https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/intel-opencl-icd_24.39.31294.12_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/libigdgmm12_22.5.2_amd64.deb && \
    dpkg -i *.deb

RUN apt install libtbb12
RUN mkdir npu-driver && \
    cd npu-driver && \
    wget https://github.com/intel/linux-npu-driver/releases/download/v1.5.1/intel-driver-compiler-npu_1.5.1.20240708-9842236399_ubuntu22.04_amd64.deb && \
    wget https://github.com/intel/linux-npu-driver/releases/download/v1.5.1/intel-fw-npu_1.5.1.20240708-9842236399_ubuntu22.04_amd64.deb && \
    wget https://github.com/intel/linux-npu-driver/releases/download/v1.5.1/intel-level-zero-npu_1.5.1.20240708-9842236399_ubuntu22.04_amd64.deb && \
    dpkg -i *.deb

RUN wget https://github.com/oneapi-src/level-zero/releases/download/v1.17.6/level-zero_1.17.6+u22.04_amd64.deb && \
    dpkg -i level-zero*.deb
RUN pip install "transformers>=4.35" "torch>=2.1" onnx "git+https://github.com/huggingface/optimum-intel.git" "peft==0.6.2" --extra-index-url https://download.pytorch.org/whl/cpu
RUN rm -r *.deb neo npu-driver

ARG RENDER_GROUP_ID
RUN groupadd -g ${RENDER_GROUP_ID} render
COPY requirements.txt .
RUN python3 -m pip install -r requirements.txt

COPY . .

HEALTHCHECK --interval=60s --timeout=180s --start-period=5s --retries=3 \
    CMD wget --no-verbose --no-proxy -O /dev/null --tries=1 http://stt_service:5996/healthcheck || exit 1
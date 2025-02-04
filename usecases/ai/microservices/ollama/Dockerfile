# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM intel/oneapi-basekit:2024.2.1-0-devel-ubuntu22.04

WORKDIR /opt/intel/llm-app
RUN rm -rf /etc/apt/sources.list.d/intel-graphics.list \
    && apt update \
    && apt install -y python3.11 \
        python3.11-venv \
        wget \
    && rm -rf /var/lib/apt/lists/* \
    && python3.11 -m venv .venv

RUN mkdir neo && cd neo \
    && wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.5.6/intel-igc-core-2_2.5.6+18417_amd64.deb \
    && wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.5.6/intel-igc-opencl-2_2.5.6+18417_amd64.deb \
    && wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-level-zero-gpu-dbgsym_1.6.32224.5_amd64.ddeb \
    && wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-level-zero-gpu_1.6.32224.5_amd64.deb \
    && wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-opencl-icd-dbgsym_24.52.32224.5_amd64.ddeb \
    && wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-opencl-icd_24.52.32224.5_amd64.deb \
    && wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/libigdgmm12_22.5.5_amd64.deb \
    && dpkg -i *.deb

ENV PATH="/opt/intel/llm-app/.venv/bin:$PATH"
ENV LD_LIBRARY_PATH=".:$LD_LIBRARY_PATH"
RUN python3 -m pip install --upgrade pip \
    && python3 -m pip install --pre --upgrade 'ipex-llm[cpp]==2.2.0b20241216' \
    && python3 -m pip install --upgrade accelerate==0.33.0 \
    && init-ollama

HEALTHCHECK --interval=60s --timeout=5m --start-period=5s --retries=5 \
    CMD curl --fail http://localhost:11434 || exit 1

CMD ["./ollama", "serve"]

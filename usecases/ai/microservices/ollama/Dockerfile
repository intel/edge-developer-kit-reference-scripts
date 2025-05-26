# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM intel/oneapi-basekit:2025.1.1-0-devel-ubuntu24.04
ARG IPEX_LLM_VERSION=2.3.0b20250520

WORKDIR /neo
RUN curl -LO https://github.com/intel/intel-graphics-compiler/releases/download/v2.11.7/intel-igc-core-2_2.11.7+19146_amd64.deb \
    && curl -LO https://github.com/intel/intel-graphics-compiler/releases/download/v2.11.7/intel-igc-opencl-2_2.11.7+19146_amd64.deb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/25.18.33578.6/intel-ocloc-dbgsym_25.18.33578.6-0_amd64.ddeb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/25.18.33578.6/intel-ocloc_25.18.33578.6-0_amd64.deb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/25.18.33578.6/intel-opencl-icd-dbgsym_25.18.33578.6-0_amd64.ddeb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/25.18.33578.6/intel-opencl-icd_25.18.33578.6-0_amd64.deb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/25.18.33578.6/libigdgmm12_22.7.0_amd64.deb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/25.18.33578.6/libze-intel-gpu1-dbgsym_25.18.33578.6-0_amd64.ddeb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/25.18.33578.6/libze-intel-gpu1_25.18.33578.6-0_amd64.deb \
    && dpkg -i *.deb

WORKDIR /opt/intel/llm-app
RUN apt update \
    && apt install -y python3-venv \
        python3-pip \
        wget \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m venv .venv
 
RUN mkdir -p /home/ubuntu/.ollama \
    && chown -R ubuntu:ubuntu /home/ubuntu/.ollama \
    && chown -R ubuntu:ubuntu /opt/intel/llm-app
    
USER ubuntu
ENV PATH="/opt/intel/llm-app/.venv/bin:$PATH"
ENV LD_LIBRARY_PATH=".:$LD_LIBRARY_PATH"
RUN python3 -m pip install --upgrade pip \
    && python3 -m pip install --pre --upgrade ipex-llm[cpp]==${IPEX_LLM_VERSION} \
    && python3 -m pip install --upgrade accelerate==0.33.0 \
    && init-ollama

HEALTHCHECK --interval=60s --timeout=5m --start-period=5s --retries=5 \
    CMD curl --fail http://localhost:11434 || exit 1

CMD ["./ollama", "serve"]
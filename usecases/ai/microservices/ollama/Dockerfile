# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM intel/oneapi-basekit:2024.2.1-0-devel-ubuntu22.04

WORKDIR /opt/intel/llm-app
RUN apt update \
    && apt install -y python3.11-venv \
    wget \
    && wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg \
    && echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | tee /etc/apt/sources.list.d/intel-gpu-jammy.list \
    && apt update \
    && apt-get install -y libze1 intel-level-zero-gpu intel-opencl-icd clinfo \
    && rm -rf /var/lib/apt/lists/* \
    && python3.11 -m venv .venv
ENV PATH="/opt/intel/llm-app/.venv/bin:$PATH"
RUN python3 -m pip install --upgrade pip \
    && python3 -m pip install --pre --upgrade 'ipex-llm[cpp]==2.2.0b20240917' \
    && python3 -m pip install bigdl-core-cpp==2.6.0b20240917 \
    && python3 -m pip install --upgrade accelerate==0.33.0 \
    && init-ollama

CMD ["/opt/intel/llm-app/ollama", "serve"]

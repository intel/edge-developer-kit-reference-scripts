# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM intel/oneapi-basekit:2025.0.2-0-devel-ubuntu24.04
ARG IPEX_LLM_VERSION=2.2.0b20250319

WORKDIR /opt/intel/llm-app
RUN apt update \
    && apt install -y python3-venv \
        python3-pip \
        wget \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m venv .venv

USER intel
ENV PATH="/opt/intel/llm-app/.venv/bin:$PATH"
ENV LD_LIBRARY_PATH=".:$LD_LIBRARY_PATH"
RUN python3 -m pip install --upgrade pip \
    && python3 -m pip install --pre --upgrade ipex-llm[cpp]==${IPEX_LLM_VERSION} \
    && python3 -m pip install --upgrade accelerate==0.33.0 \
    && init-ollama

HEALTHCHECK --interval=60s --timeout=5m --start-period=5s --retries=5 \
    CMD curl --fail http://localhost:11434 || exit 1

CMD ["./ollama", "serve"]

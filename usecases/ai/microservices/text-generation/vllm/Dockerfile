# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM debian:12-slim
ARG DEBIAN_FRONTEND=noninteractive
ARG VLLM_VERSION=v0.6.6
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install --no-install-recommends -y \
        sudo \
        curl \
        git \
        gpg-agent \
        software-properties-common \
        python3.11 \
        python3.11-venv \
    && curl -fsSL https://repositories.intel.com/gpu/intel-graphics.key | gpg --dearmor | tee /usr/share/keyrings/intel-graphics.gpg \
    && echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" > /etc/apt/sources.list.d/intel-graphics.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        intel-opencl-icd \
        intel-level-zero-gpu \
        libze1 \
        libze-dev \
        clinfo \
    && addgroup --system intel --gid 1000 \
    && adduser --system --ingroup intel --uid 1000 --home /home/intel intel \
    && echo "intel ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/intel \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /usr/src/app/data \
    && chown -R intel:intel /usr/src

USER intel
WORKDIR /usr/src/app
RUN python3 -m venv /usr/src/.venv \
    && git clone https://github.com/vllm-project/vllm.git
ENV PATH="/usr/src/.venv/bin:$PATH"

WORKDIR /usr/src/app/vllm
RUN git checkout ${VLLM_VERSION} \
    && python3 -m pip install --no-cache-dir --upgrade pip \
    && python3 -m pip install --no-cache-dir --extra-index-url https://download.pytorch.org/whl/cpu -r requirements-build.txt
COPY --chown=intel:intel patch/openvino.txt requirements-openvino.txt
RUN VLLM_TARGET_DEVICE="openvino" python3 -m pip install --no-cache-dir --extra-index-url https://download.pytorch.org/whl/cpu .

WORKDIR /usr/src/app
RUN opt_in_out --opt_out
COPY --chown=intel:intel entrypoint.sh /usr/src/app/entrypoint.sh
RUN chmod +x /usr/src/app/entrypoint.sh

HEALTHCHECK --interval=1m --timeout=30s --start-period=5s --retries=10 \
    CMD curl -f http://localhost:8000/health || exit 1

ENTRYPOINT [ "/usr/src/app/entrypoint.sh" ]
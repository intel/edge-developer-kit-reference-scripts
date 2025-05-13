# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM debian:12-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG RENDER_GROUP_ID
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install --no-install-recommends -y \
    sudo \
    wget \
    ca-certificates \
    ffmpeg \
    libsm6 \
    libxext6 \
    curl \
    git \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    llvm \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    gnupg \
    && addgroup --system intel --gid 1000 \
    && adduser --system --ingroup intel --uid 1000 --home /home/intel intel \
    && echo "intel ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/intel \
    && groupadd -g ${RENDER_GROUP_ID} render \
    && usermod -aG render intel \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /usr/src \
    && chown -R intel:intel /usr/src

# Intel GPU Driver 
RUN curl -s https://repositories.intel.com/gpu/intel-graphics.key | \
        gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg \
    && echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy unified" | \
        tee /etc/apt/sources.list.d/intel-gpu-jammy.list \
    && apt update && apt-get install --no-install-recommends -y libze-intel-gpu1 libze1 intel-opencl-icd clinfo

WORKDIR /neo
RUN curl -LO https://github.com/intel/intel-graphics-compiler/releases/download/v2.5.6/intel-igc-core-2_2.5.6+18417_amd64.deb \
    && curl -LO https://github.com/intel/intel-graphics-compiler/releases/download/v2.5.6/intel-igc-opencl-2_2.5.6+18417_amd64.deb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-level-zero-gpu-dbgsym_1.6.32224.5_amd64.ddeb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-level-zero-gpu_1.6.32224.5_amd64.deb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-opencl-icd-dbgsym_24.52.32224.5_amd64.ddeb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-opencl-icd_24.52.32224.5_amd64.deb \
    && curl -LO https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/libigdgmm12_22.5.5_amd64.deb \
    && apt purge -y libze-intel-gpu1 \
    && dpkg -i *.deb

USER intel
WORKDIR /usr/src/app

# Set environment variables for pyenv
ENV PYENV_ROOT="/usr/src/app/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

# Install pyenv
RUN curl https://pyenv.run | bash \
    && echo 'export PYENV_ROOT="$PYENV_ROOT"' >> ~/.bashrc \
    && echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc \
    && echo 'eval "$(pyenv init --path)"' >> ~/.bashrc \
    && echo 'eval "$(pyenv init -)"' >> ~/.bashrc \
    && . ~/.bashrc \
    && pyenv install 3.10.15 \
    && pyenv global 3.10.15

RUN python3 -m pip install --upgrade pip 
COPY ./backend/wav2lip/requirements.txt .
RUN python3 -m pip install --no-cache-dir -r requirements.txt

COPY --chown=intel ./backend/wav2lip .
COPY --chown=intel ./weights/wav2lip_gan.pth ./setup/
RUN mkdir -p data && mkdir -p assets
RUN ./setup.sh
RUN python3 setup/download_model.py

RUN mkdir -p /usr/src/RealESRGan
COPY --chown=intel ./backend/RealESRGan /usr/src/RealESRGan
RUN bash /usr/src/RealESRGan/setup.sh

HEALTHCHECK --interval=30s --timeout=180s --start-period=60s --retries=5 \
    CMD sh -c 'PORT=${SERVER_PORT:-8011} && wget --no-verbose -O /dev/null --tries=1 http://localhost:$PORT/healthcheck || exit 1'
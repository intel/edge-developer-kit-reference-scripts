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
    && rm -rf /var/lib/apt/lists/* 

RUN apt-get update && apt-get install python3 python3-venv -y

RUN python3 -m venv /.venv
ENV PATH="/.venv/bin:$PATH"

COPY . .
RUN python3 -m pip install -r requirements.txt
RUN python3 -m pip install -r requirements-piper.txt --no-deps

HEALTHCHECK --interval=30s --timeout=180s --start-period=60s --retries=3 \
    CMD sh -c 'PORT=${SERVER_PORT:-8013} && wget --no-verbose -O /dev/null --tries=1 http://localhost:$PORT/healthcheck || exit 1'
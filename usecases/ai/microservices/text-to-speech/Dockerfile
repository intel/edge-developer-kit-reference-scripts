# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM python:3.11-slim

USER root
RUN useradd -m intel

# Install dependencies
WORKDIR /opt
RUN apt-get update && apt-get install -y \
    build-essential libsndfile1 git wget \
    && rm -rf /var/lib/apt/lists/*

# Install Melo TTS
RUN mkdir -p thirdparty && \
    cd thirdparty && \
    git clone https://github.com/myshell-ai/MeloTTS.git && \
    cd MeloTTS && \
    pip install -e . && \
    python -m unidic download

WORKDIR /usr/src/app
COPY requirements.txt .
RUN python3 -m pip install -r requirements.txt
COPY . .

ENV NLTK_DATA="/usr/src/app/data/nltk_data"

HEALTHCHECK --interval=30s --timeout=180s --start-period=50s --retries=5 \
    CMD wget --no-verbose --no-proxy -O /dev/null --tries=1 http://tts_service:5995/healthcheck || exit 1

CMD ["python3", "-m", "uvicorn", "main:app", "--host", "tts_service", "--port", "5995"]

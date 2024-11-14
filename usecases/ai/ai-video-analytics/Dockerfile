# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM debian:12-slim 
ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install --no-install-recommends -y \
    sudo \
    wget \
    gnupg2 \
    python3.11 \
    python3.11-venv \
    libgl1-mesa-dev \
    libglib2.0-0 \
    && addgroup --system intel --gid 1000 \
    && adduser --system --ingroup intel --uid 1000 --home /home/intel intel \
    && echo "intel ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/intel \
    && addgroup --system docker --gid 999 \
    && usermod -aG docker intel \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /usr/src \
    && chown -R intel:intel /usr/src

RUN wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
    gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg
RUN echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | \
    tee /etc/apt/sources.list.d/intel-gpu-jammy.list
RUN apt-get update \
    && apt-get install -y libze1 intel-level-zero-gpu intel-opencl-icd clinfo


USER intel
WORKDIR /usr/src/app
COPY --chown=intel:intel ./ /usr/src/app
RUN python3 -m venv /usr/src/.venv
ENV PATH="/usr/src/.venv/bin:$PATH"
RUN python3 -m pip install --no-cache-dir --upgrade pip \
    && python3 -m pip install --no-cache-dir -r requirements.txt
RUN mkdir -p ./data/model/facial_recognition
RUN wget -O ./data/model/facial_recognition/face-detection-retail-0004.xml https://storage.openvinotoolkit.org/repositories/open_model_zoo/2023.0/models_bin/1/face-detection-retail-0004/FP32/face-detection-retail-0004.xml
RUN wget -O ./data/model/facial_recognition/face-detection-retail-0004.bin https://storage.openvinotoolkit.org/repositories/open_model_zoo/2023.0/models_bin/1/face-detection-retail-0004/FP32/face-detection-retail-0004.bin
RUN wget -O ./data/model/facial_recognition/landmarks-regression-retail-0009.xml https://storage.openvinotoolkit.org/repositories/open_model_zoo/2023.0/models_bin/1/landmarks-regression-retail-0009/FP32/landmarks-regression-retail-0009.xml
RUN wget -O ./data/model/facial_recognition/landmarks-regression-retail-0009.bin https://storage.openvinotoolkit.org/repositories/open_model_zoo/2023.0/models_bin/1/landmarks-regression-retail-0009/FP32/landmarks-regression-retail-0009.bin

EXPOSE 5980

CMD ["python","app.py"]

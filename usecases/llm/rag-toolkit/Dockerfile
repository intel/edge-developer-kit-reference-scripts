# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM intel/oneapi-basekit:2024.0.1-devel-ubuntu22.04
USER root

RUN rm /etc/apt/sources.list.d/intel-graphics.list
RUN apt update
RUN wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
RUN echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | tee /etc/apt/sources.list.d/oneAPI.list
RUN apt update

# Create new user
RUN apt update && apt install -y sudo software-properties-common pciutils
RUN groupadd -g 110 render
RUN useradd -m intel
RUN usermod -aG sudo intel
# Set user to have sudo privileges
RUN echo "intel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER intel
WORKDIR /home/intel
ENV USER=intel

# Install python 3.11
ARG DEBIAN_FRONTEND=noninteractive
RUN sudo -E apt update && sudo -E apt install -y python3.11 python3.11-dev python3.11-venv python3-pip
RUN python3.11 -m pip install --upgrade pip

# Install deps
COPY . .
ARG INSTALL_OPTION
ENV INSTALL_OPTION $INSTALL_OPTION
ARG HF_TOKEN
ENV HF_TOKEN $HF_TOKEN
RUN sudo chown -R intel:intel /home/intel
RUN ./install.sh
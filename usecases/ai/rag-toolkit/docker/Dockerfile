FROM intel/oneapi-basekit:2024.0.1-devel-ubuntu22.04

USER root

RUN rm /etc/apt/sources.list.d/intel-graphics.list
RUN wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
RUN echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | tee /etc/apt/sources.list.d/oneAPI.list
RUN apt update && apt upgrade -y && apt install -y sudo software-properties-common pciutils

# Install python 3.11
ARG DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y python3.11 python3.11-dev python3.11-venv python3-pip
RUN python3.11 -m pip install --upgrade pip

# Create new user
RUN groupadd -g 110 render
RUN useradd -m intel
RUN usermod -aG sudo intel
RUN usermod -aG render intel
# Set user to have sudo privileges
RUN echo "intel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# GPU Driver Installation
RUN wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
        gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg && \
    echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | \
        tee /etc/apt/sources.list.d/intel-gpu-jammy.list && \
    apt update && \
    apt-get install -y --no-install-recommends libze1 intel-level-zero-gpu intel-opencl-icd clinfo libze-dev intel-ocloc

USER intel
WORKDIR /home/intel
ENV USER=intel

# Install deps
COPY --chown=intel  . .
RUN mv docker/run-serving.sh ./
RUN chown -R intel:intel /home/intel

ARG INSTALL_OPTION=2
ENV INSTALL_OPTION=$INSTALL_OPTION
ARG HF_TOKEN=""
ENV HF_TOKEN=$HF_TOKEN
RUN ./install.sh
# Unset the HF_TOKEN after installation
ENV HF_TOKEN=

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD wget --no-verbose -O /dev/null --tries=1 http://localhost:8011/healthcheck || exit 1
####################################################################################
# Copyright (C) <2025> Intel Corporation
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 3. Neither the name of the copyright holder nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
# OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# SPDX-License-Identifier: BSD-3-Clause
###################################################################################
FROM ubuntu:24.04

# Update
RUN apt update
RUN apt upgrade -y

# Update package list and install dependencies
RUN apt update && apt install -y \
    build-essential \
    cmake \
    git \
    msr-tools \
    vim \
    sudo

# Clone the cJOSN repository and build and install the library
RUN git clone https://github.com/DaveGamble/cJSON.git && \
    cd cJSON && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make && \
    make install && \
    ldconfig

# Clone the paho.mqqt.c repository and build and install the library
RUN git clone https://github.com/eclipse/paho.mqtt.c.git && \
    cd paho.mqtt.c && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make && \
    make install && \
    ldconfig

# Install and build 
WORKDIR /root
RUN git clone https://github.com/intel/edge-developer-kit-reference-scripts.git
WORKDIR /root/edge-developer-kit-reference-scripts/usecases/real-time/tcc_tutorial
RUN make 
RUN ls -l /root/edge-developer-kit-reference-scripts/usecases/real-time/tcc_tutorial
# Give execute permissions to the file
RUN chmod +x /root/edge-developer-kit-reference-scripts/usecases/real-time/tcc_tutorial/rt_linux_tutorial

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD npm --version || exit 1
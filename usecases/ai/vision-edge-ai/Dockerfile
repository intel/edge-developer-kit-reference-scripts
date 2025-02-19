# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM ubuntu:24.10

ARG DEBIAN_FRONTEND=noninteractive
USER root

#--------------------------------------------------------------------------------------------------------------------------
# Essential Tools
#--------------------------------------------------------------------------------------------------------------------------

RUN apt update -y && apt install -y \
    software-properties-common \
    build-essential \
    wget \
    gpg \
    curl \
    pciutils \
    git \
    cmake \
    libopencv-dev \
    v4l-utils \
    libusb-1.0-0-dev \
    libssl-dev \
    libgtk-3-dev \
    pkg-config \
    udev \
    libudev-dev \
    libglfw3-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    python3-pip \
    python3-dev \
    python3-setuptools \
    python3-opencv 

#--------------------------------------------------------------------------------------------------------------------------
# Graphic & NPU drivers and tools
#--------------------------------------------------------------------------------------------------------------------------

# Install Intel GPU Drivers
RUN wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
    gpg --dearmor --output /usr/share/keyrings/intel-graphics.gpg && \
    echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] \
         https://repositories.intel.com/gpu/ubuntu noble client" \
    > /etc/apt/sources.list.d/intel-gpu-noble.list && \
    apt update -y && apt install -y libze1 intel-level-zero-gpu intel-opencl-icd clinfo

# Install Intel NPU Drivers
WORKDIR /tmp
RUN apt install -y libtbb12
RUN wget https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-driver-compiler-npu_1.10.0.20241107-11729849322_ubuntu24.04_amd64.deb \
    https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-fw-npu_1.10.0.20241107-11729849322_ubuntu24.04_amd64.deb \
    https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-level-zero-npu_1.10.0.20241107-11729849322_ubuntu24.04_amd64.deb && \
    dpkg -i *.deb && rm -f *.deb

# Install Intel PCM Tool
RUN git clone --recursive https://github.com/intel/pcm && \
    cd pcm && mkdir build && cd build && \
    cmake .. && cmake --build . --parallel && make install && \
    rm -rf /tmp/pcm

#--------------------------------------------------------------------------------------------------------------------------
# OpenVINO 
#--------------------------------------------------------------------------------------------------------------------------

WORKDIR /opt/intel
# Install OpenVINO
RUN curl -L https://storage.openvinotoolkit.org/repositories/openvino/packages/2024.5/linux/l_openvino_toolkit_ubuntu24_2024.5.0.17288.7975fa5da0c_x86_64.tgz \
  --output openvino.tgz
RUN tar -xf openvino.tgz
RUN mv l_openvino_toolkit_ubuntu24_2024.5.0.17288.7975fa5da0c_x86_64 openvino
RUN cd openvino && sed -i 's/24\.04/24\.10/g'  ./install_dependencies/install_openvino_dependencies.sh && \
    bash ./install_dependencies/install_openvino_dependencies.sh -y
ENV OPENVINO_DIR=/opt/intel/openvino
RUN pip install --pre -U openvino openvino-dev --extra-index-url https://storage.openvinotoolkit.org/simple/wheels/nightly --break-system-packages

#--------------------------------------------------------------------------------------------------------------------------
# librealsense
#--------------------------------------------------------------------------------------------------------------------------

WORKDIR /tmp
RUN git clone https://github.com/IntelRealSense/librealsense

RUN cd librealsense && mkdir build && cd build && \
    cmake .. -DBUILD_PYTHON_BINDINGS=ON -DPYTHON_EXECUTABLE=$(which python3) && \
    make -j$(nproc) && \
    make install && \
    ldconfig 

#python3 -m pip install --no-cache-dir pyrealsense2 --break-system-packages

ENV PYTHONPATH=/usr/local/lib/python3.12/dist-packages

#--------------------------------------------------------------------------------------------------------------------------
# Required Python Packages
#--------------------------------------------------------------------------------------------------------------------------

RUN pip3 install --break-system-packages \
    fire \
    distro \
    zeroconf \
    psutil \
    cython \
    prometheus-client \
    zeroconf  

RUN pip3 install --break-system-packages \
    yt-dlp \
    youtube_dl \
    pafy 

RUN apt remove -y python3-blinker || true
RUN pip3 install --break-system-packages \
    flask \
    flask_bootstrap

RUN pip3 install --break-system-packages \
    nncf \
    ultralytics 

#--------------------------------------------------------------------------------------------------------------------------
# Video Steams Download
#--------------------------------------------------------------------------------------------------------------------------

WORKDIR /opt/videos

RUN wget -O streat.mp4 https://videos.pexels.com/video-files/3759216/3759216-sd_640_360_30fps.mp4
#RUN wget -O animals.mp4 https://videos.pexels.com/video-files/4938060/4938060-uhd_2732_1440_30fps.mp4

#--------------------------------------------------------------------------------------------------------------------------
# Models Preparation
#--------------------------------------------------------------------------------------------------------------------------

WORKDIR /opt/models

COPY ./utils/models.sh /tmp/
RUN /tmp/models.sh 



RUN rm -rf /tmp/*

WORKDIR /workspace



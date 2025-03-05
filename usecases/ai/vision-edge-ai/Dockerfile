# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM ubuntu:24.04
ARG DEBIAN_FRONTEND=noninteractive

#=======================================
# Core System Setup
#=======================================
RUN apt update -y && apt install -y \
    software-properties-common build-essential wget gpg pciutils git cmake \
    libglib2.0-0 libtbb12 v4l-utils libusb-1.0-0-dev libssl-dev libgtk-3-dev pkg-config \
    udev libudev-dev libglfw3-dev libgl1-mesa-dev libglu1-mesa-dev libva-dev yasm libx264-dev libx265-dev \
    sudo

#=======================================
# Install Python 3.9 
#=======================================
RUN add-apt-repository ppa:deadsnakes/ppa && apt update -y && \
    apt install -y python3.9 python3.9-distutils python3.9-dev && \
    rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1
RUN ln -sf /usr/bin/python3 /usr/bin/python

RUN wget https://bootstrap.pypa.io/get-pip.py && \
    python3.9 get-pip.py && \
    rm get-pip.py

# Install system-wide python3-numpy for OpenCV build
RUN apt update -y && apt install -y python3-numpy

# Install pip dependencies, ensuring NumPy is compatible with Python 3.9
RUN python3.9 -m pip install --upgrade pip setuptools wheel 
#=======================================
# Intel GPU Drivers
#=======================================
RUN wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
    gpg --yes --dearmor -o /usr/share/keyrings/intel-graphics.gpg && \
    echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu noble unified" > \
    /etc/apt/sources.list.d/intel-gpu-noble.list && \
    apt update && apt install -y \
    libze-intel-gpu1 libze1 intel-opencl-icd clinfo intel-gsc \
    && rm -rf /var/lib/apt/lists/*

#=======================================
# Intel NPU Drivers
#=======================================
RUN wget -qP /tmp \
        https://github.com/intel/linux-npu-driver/releases/download/v1.13.0/intel-driver-compiler-npu_1.13.0.20250131-13074932693_ubuntu24.04_amd64.deb \
        https://github.com/intel/linux-npu-driver/releases/download/v1.13.0/intel-fw-npu_1.13.0.20250131-13074932693_ubuntu24.04_amd64.deb \
        https://github.com/intel/linux-npu-driver/releases/download/v1.13.0/intel-level-zero-npu_1.13.0.20250131-13074932693_ubuntu24.04_amd64.deb && \
    dpkg -i /tmp/*.deb && rm -f /tmp/*.deb

#=======================================
# Intel Performance Tools
#=======================================
RUN git clone --recursive https://github.com/intel/pcm /tmp/pcm && \
    cmake -S /tmp/pcm -B /tmp/pcm/build && \
    cmake --build /tmp/pcm/build --parallel && \
    make -C /tmp/pcm/build install && rm -rf /tmp/pcm

#=======================================
# Compile FFmpeg with VAAPI Support
#=======================================
WORKDIR /tmp
RUN wget -q https://ffmpeg.org/releases/ffmpeg-7.0.2.tar.bz2 && \
    tar -xjf ffmpeg-7.0.2.tar.bz2 && \
    mv ffmpeg-7.0.2 ffmpeg

WORKDIR /tmp/ffmpeg
RUN ./configure \
    --prefix=/usr/local \
    --enable-gpl \
    --enable-libx264 \
    --enable-libx265 \
    --enable-vaapi \
    --enable-shared \
    && make -j$(nproc) && \
    make install && \
    ldconfig && \
    rm -rf /tmp/ffmpeg /tmp/ffmpeg-7.0.2.tar.bz2

#=======================================
# OpenCV Compilation 
#=======================================
WORKDIR /tmp
RUN git clone https://github.com/opencv/opencv.git
RUN git clone https://github.com/opencv/opencv_contrib.git

WORKDIR /tmp/opencv/build
RUN cmake -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D OPENCV_EXTRA_MODULES_PATH=../../opencv_contrib/modules \
    -D WITH_VAAPI=ON \
    -D WITH_FFMPEG=ON \
    -D WITH_V4L=ON \
    -D FFMPEG_LIBRARY_DIR=/usr/local/lib \
    -D FFMPEG_INCLUDE_DIR=/usr/local/include \
    -D PYTHON_EXECUTABLE=$(which python3) \
    -D BUILD_TESTS=OFF \
    -D BUILD_PERF_TESTS=OFF \
    -D BUILD_EXAMPLES=OFF \
    -D INSTALL_PYTHON_EXAMPLES=OFF \
    -D INSTALL_C_EXAMPLES=OFF \
    -D WITH_CUDA=OFF \
    -D WITH_GTK=OFF \
    -D WITH_QT=OFF \
    -D WITH_GSTREAMER=OFF \
    -D WITH_DNN=OFF \
    -D WITH_GAPI=OFF \
    .. && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    rm -rf /tmp/opencv /tmp/opencv*

#=======================================
# RealSense SDK
#=======================================
WORKDIR /tmp
RUN git clone https://github.com/IntelRealSense/librealsense

RUN cd librealsense && mkdir build && cd build && \
    cmake .. -DBUILD_PYTHON_BINDINGS=ON -DPYTHON_EXECUTABLE=$(which python3) && \
    make -j$(nproc) && \
    make install && \
    ldconfig 

RUN apt install -y sudo
RUN cd /tmp/librealsense && ./scripts/setup_udev_rules.sh

RUN python3.9 -m pip install pyrealsense2

#=======================================
# Python Environment
#=======================================
RUN apt remove -y python3-blinker || true

RUN python3.9 -m pip  install  \
    fire distro zeroconf psutil cython prometheus-client \
    yt-dlp youtube_dl pafy flask flask_bootstrap nncf ultralytics

RUN python3.9 -m pip install --pre -U openvino openvino-dev[onnx] \
    --extra-index-url https://storage.openvinotoolkit.org/simple/wheels/nightly 

#=======================================
# Web Assets
#=======================================
WORKDIR /workspace/static
RUN mkdir -p js css && \
    wget -O js/jquery.min.js https://cdnjs.cloudflare.com/ajax/libs/jquery/3.4.0/jquery.min.js && \
    wget -O js/moment.min.js https://cdnjs.cloudflare.com/ajax/libs/moment.js/2.29.1/moment.min.js && \
    wget -O js/bootstrap-datetimepicker.min.js https://cdnjs.cloudflare.com/ajax/libs/bootstrap-datetimepicker/4.17.47/js/bootstrap-datetimepicker.min.js && \
    wget -O js/turf.min.js https://unpkg.com/@turf/turf@6.2.0-alpha.1/dist/turf.min.js && \
    wget -O js/jqxcore.js https://jqwidgets.com/public/jqwidgets/jqxcore.js && \
    wget -O js/jqxdraw.js https://jqwidgets.com/public/jqwidgets/jqxdraw.js && \
    wget -O js/jqxgauge.js https://jqwidgets.com/public/jqwidgets/jqxgauge.js && \
    wget -O css/bootstrap.min.css https://maxcdn.bootstrapcdn.com/bootstrap/4.0.0/css/bootstrap.min.css && \
    wget -O css/bootstrap-datetimepicker.min.css https://cdnjs.cloudflare.com/ajax/libs/bootstrap-datetimepicker/4.17.47/css/bootstrap-datetimepicker.min.css && \
    wget -O css/chart.min.css https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.8.0/Chart.min.css

#=======================================
# Video Streams
#=======================================
WORKDIR /opt/videos
RUN wget -O tmp.mp4 https://videos.pexels.com/video-files/17476835/17476835-hd_1920_1080_30fps.mp4 && \
    ffmpeg -i tmp.mp4 -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2" -c:a copy video_1.mp4 && \
    wget -O tmp.mp4 https://videos.pexels.com/video-files/4997787/4997787-hd_1920_1080_24fps.mp4 && \
    ffmpeg -i tmp.mp4 -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2" -c:a copy video_2.mp4 && \
    rm -f tmp.mp4

#=======================================
# Numpy for python 3.9
#=======================================
RUN apt remove -y python3-numpy
RUN python3.9 -m pip install "numpy>=2.0.0" 

#=======================================
# Model Installation & Build
#=======================================
ENV PATH=/home/intel/.local/bin:${PATH}
COPY --chown=intel:intel ./utils/models.sh /tmp/
WORKDIR /opt/models
RUN bash /tmp/models.sh
WORKDIR /workspace/utils

#=======================================
# Application Setup
#=======================================
WORKDIR /workspace

COPY --chown=intel:intel ./app.py /workspace/
COPY --chown=intel:intel ./static /workspace/static/
COPY --chown=intel:intel ./templates /workspace/templates/
COPY --chown=intel:intel ./utils/*.py* /workspace/utils/

WORKDIR /workspace/utils
RUN python3 setup.py build_ext --quiet --inplace

#=======================================
# Create default user 'intel'
#=======================================
RUN useradd -m -s /bin/bash intel && chown -R intel:intel /home/intel
RUN echo "intel ALL=(root) NOPASSWD: /usr/local/sbin/pcm" >> /etc/sudoers
RUN groupadd -f render 
RUN groupadd -f video
RUN usermod -a -G video intel
RUN usermod -a -G render intel

#USER intel

WORKDIR /workspace

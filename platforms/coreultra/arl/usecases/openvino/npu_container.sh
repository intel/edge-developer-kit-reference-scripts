#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# Install dependencies for NPU
mkdir /tmp/npu_temp
cd /tmp/npu_temp || exit
wget https://github.com/intel/linux-npu-driver/releases/download/v1.13.0/intel-driver-compiler-npu_1.13.0.20250131-13074932693_ubuntu24.04_amd64.deb
wget https://github.com/intel/linux-npu-driver/releases/download/v1.13.0/intel-fw-npu_1.13.0.20250131-13074932693_ubuntu24.04_amd64.deb
wget https://github.com/intel/linux-npu-driver/releases/download/v1.13.0/intel-level-zero-npu_1.13.0.20250131-13074932693_ubuntu24.04_amd64.deb
wget https://github.com/oneapi-src/level-zero/releases/download/v1.18.5/level-zero_1.18.5+u24.04_amd64.deb
sudo dpkg -i ./*.deb

cd /tmp || exit
rm -rf npu_temp

exec /bin/bash
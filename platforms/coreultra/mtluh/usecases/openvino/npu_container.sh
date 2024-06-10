#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

mkdir /tmp/npu_temp
cd /tmp/npu_temp || exit
wget https://github.com/intel/linux-npu-driver/releases/download/v1.1.0/intel-driver-compiler-npu_1.1.0.20231117-6904283384_ubuntu22.04_amd64.deb
wget https://github.com/intel/linux-npu-driver/releases/download/v1.1.0/intel-fw-npu_1.1.0.20231117-6904283384_ubuntu22.04_amd64.deb
wget https://github.com/intel/linux-npu-driver/releases/download/v1.1.0/intel-level-zero-npu_1.1.0.20231117-6904283384_ubuntu22.04_amd64.deb
wget https://github.com/oneapi-src/level-zero/releases/download/v1.10.0/level-zero_1.10.0+u22.04_amd64.deb

sudo dpkg -i ./*.deb

cd /tmp || exit
rm -rf npu_temp

exec /bin/bash
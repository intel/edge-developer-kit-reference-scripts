#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

sudo apt-get install -y flex bison kernel-wedge gcc libssl-dev libelf-dev quilt liblz4-tool
git clone https://github.com/intel/linux-kernel-overlay.git
cd linux-kernel-overlay || { echo "linux-kernel-overlay folder not found"; exit 1; }
git checkout lts2022-ubuntu
./build.sh
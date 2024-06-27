#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# Setup ipu6 files
sudo cp -r out/install/include/* /usr/include
sudo cp -r out/install/lib/* /usr/lib
sudo cp -r out/install/share/* /usr/share

echo -en '\n'
echo "Added IPU6 files. Proceed with installing v4l2 API..."
echo -en '\n'
echo "Installing v4l2 API..."

# Install v4l2 API
sudo apt-get -y install v4l2loopback-dkms
sudo apt-get -y install v4l2loopback-utils

# Reboot system
# sudo reboot now

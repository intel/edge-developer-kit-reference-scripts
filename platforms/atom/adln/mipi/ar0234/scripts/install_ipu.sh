#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0 

# Install gstreamer packages
sudo apt-get -y install libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-base \
gstreamer1.0-plugins-good \
libgstreamer-plugins-good1.0-dev gstreamer1.0-plugins-bad-apps gstreamer1.0-plugins-bad \
libgstreamer-plugins-bad1.0-0 gstreamer1.0-plugins-ugly

# Dependancies for userspace libraries
sudo apt-get -y install cmake build-essential pkg-config libexpat1-dev rpm autoconf libtool

# Build ipu6-camera-bins
git clone https://github.com/intel/ipu6-camera-bins.git
cd ipu6-camera-bins/ || { echo "ipu6-camera-bins folder not found"; exit 1; }
git checkout v1.0.0-adln-mr3-6.1
cd ../
sudo cp -r ipu6-camera-bins/include/* /usr/include/
sudo cp -r ipu6-camera-bins/lib/* /usr/lib/

# Setup ipu6-camera-hal
git clone https://github.com/intel/ipu6-camera-hal.git
cd ipu6-camera-hal/ || { echo "ipu6-camera-hal folder not found"; exit 1; }
git checkout v1.0.0-adln-mr3-6.1
cp build.sh .. && cd ..

# Setup icamerasrc
sudo apt-get install libdrm-dev
git clone https://github.com/intel/icamerasrc.git
cd icamerasrc/ || { echo "icamerasrc folder not found"; exit 1; }
git checkout v1.0.0-adln-mr3-6.1
cd ../

# Build ipu6-camera-hal and icamerasrc
# shellcheck source=build.sh
chmod +x build.sh
./build.sh

echo -en '\n'
echo "Finish IPU6 installation. Proceed to run the command as follows: ./setup_ipu.sh "
echo -en '\n'



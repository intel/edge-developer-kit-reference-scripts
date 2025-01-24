#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0 

# Install the Intel graphics GPG public key
wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
  sudo gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg

# Configure the repositories.intel.com package repository
echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu noble client" | \
  sudo tee /etc/apt/sources.list.d/intel-gpu-noble.list

# Update the package repository meta-data
sudo apt update

# Install the compute-related packages
sudo apt-get install -y libze-intel-gpu1 libze1 intel-opencl-icd clinfo intel-gsc

# Install compute runtime
mkdir -p /tmp/neo_temp
cd /tmp/neo_temp || exit
wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.5.6/intel-igc-core-2_2.5.6+18417_amd64.deb
wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.5.6/intel-igc-opencl-2_2.5.6+18417_amd64.deb
wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-level-zero-gpu-dbgsym_1.6.32224.5_amd64.ddeb
wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-level-zero-gpu_1.6.32224.5_amd64.deb
wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-opencl-icd-dbgsym_24.52.32224.5_amd64.ddeb
wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-opencl-icd_24.52.32224.5_amd64.deb
wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/libigdgmm12_22.5.5_amd64.deb
   
echo -e "Verify sha256 sums for packages"
wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/ww52.sum
sha256sum -c ww52.sum

echo -e "\nInstalling compute runtime as root"
sudo apt remove -y intel-ocloc libze-intel-gpu1
sudo dpkg -i ./*.deb 

cd /tmp || exit
echo -e "Cleaning up /tmp/neo_temp folder after installation"
rm -rf neo_temp
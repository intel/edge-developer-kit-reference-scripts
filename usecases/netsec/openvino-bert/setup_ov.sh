#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -e

# symbol
S_VALID="✓"
#S_INVALID="✗"

# verify current user
if [ "$EUID" -eq 0 ]; then
    echo "Must not run with sudo or root user"
    exit 1
fi

CURRENT_DIR=$(pwd)

install_packages(){
    local PACKAGES=("$@")
    local INSTALL_REQUIRED=0
    for PACKAGE in "${PACKAGES[@]}"; do
        INSTALLED_VERSION=$(dpkg-query -W -f='${Version}' "$PACKAGE" 2>/dev/null || true)
        LATEST_VERSION=$(apt-cache policy "$PACKAGE" | grep Candidate | awk '{print $2}')
        
        if [ -z "$INSTALLED_VERSION" ] || [ "$INSTALLED_VERSION" != "$LATEST_VERSION" ]; then
            echo "$PACKAGE is not installed or not the latest version."
            INSTALL_REQUIRED=1
        fi
    done
    if [ $INSTALL_REQUIRED -eq 1 ]; then
        sudo -E apt update
        sudo -E apt install -y "${PACKAGES[@]}"
    fi
}

verify_dependencies_ov(){
    echo -e "# Verifying OV dependencies"
    DEPENDENCIES_PACKAGES=(
        zip
        wget
        numactl
        python3-pip
        python3-venv
        python3-opencv
    )
    install_packages "${DEPENDENCIES_PACKAGES[@]}"
    echo "$S_VALID Dependencies installed";
}
#verify conda
verify_conda() {
    mkdir -p "$HOME"/miniconda3
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
    bash "$HOME"/miniconda3/miniconda.sh -b -u -p ~/miniconda3
    rm -rf "$HOME"/miniconda3/miniconda.sh
    "$HOME"/miniconda3/bin/conda init bash
    "$HOME"/miniconda3/bin/conda config --set auto_activate_base false
    # shellcheck source=/dev/null
    source ~/.bashrc
}

#verify gpu
verify_gpu() {
    mkdir "$HOME"/neo
    cd "$HOME"/neo
    wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.15985.7/intel-igc-core_1.0.15985.7_amd64.deb
    wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.15985.7/intel-igc-opencl_1.0.15985.7_amd64.deb
    wget https://github.com/intel/compute-runtime/releases/download/24.05.28454.6/intel-level-zero-gpu-dbgsym_1.3.28454.6_amd64.ddeb
    wget https://github.com/intel/compute-runtime/releases/download/24.05.28454.6/intel-level-zero-gpu_1.3.28454.6_amd64.deb
    wget https://github.com/intel/compute-runtime/releases/download/24.05.28454.6/intel-opencl-icd-dbgsym_24.05.28454.6_amd64.ddeb
    wget https://github.com/intel/compute-runtime/releases/download/24.05.28454.6/intel-opencl-icd_24.05.28454.6_amd64.deb
    wget https://github.com/intel/compute-runtime/releases/download/24.05.28454.6/libigdgmm12_22.3.11_amd64.deb
    sudo dpkg -i ./*.deb
}

verify_ov() {
    cd "$CURRENT_DIR"
    python3 -m venv bert_ov_venv
    # shellcheck source=/dev/null
    source bert_ov_venv/bin/activate
    pip install -U pip
    pip install -r requirements.txt
    python torch-to-ov.py
}


setup() {
    verify_dependencies_ov
    verify_conda
    verify_gpu
    verify_ov
    
    echo -e "\n# Status"
    echo "$S_VALID OpenVINO™ configured"
}

setup

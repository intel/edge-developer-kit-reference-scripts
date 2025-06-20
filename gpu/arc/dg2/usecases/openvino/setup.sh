#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0 

set -e

# symbol
S_VALID="✓"

# verify current user
if [ "$EUID" -eq 0 ]; then
    echo "Must not run with sudo or root user"
    exit 1
fi

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

verify_dependencies(){
    echo -e "\n# Verifying dependencies"
    DEPENDENCIES_PACKAGES=(
        python3-pip
        python3-venv
    )
    install_packages "${DEPENDENCIES_PACKAGES[@]}"
    echo "$S_VALID Dependencies installed"
}

setup_docker(){

    if ! id -nG "$USER" | grep -q -w '\<docker\>'; then
        echo -e "\n# Add $USER into docker group"
        sudo groupadd docker
        sudo usermod -aG docker "$USER"
        echo "System reboot is required. Re-run the script after reboot"
        exit 0
    fi
}

install_openvino_docker(){

    echo -e "\n# Install OpenVINO™ Runtime docker image"
    if ! docker images | grep openvino/ubuntu24_dev; then
        if ! docker images | grep openvino_dgpu/ubuntu24_dev; then
            docker pull openvino/ubuntu24_dev:latest
            echo "Default OpenVINO™ Runtime docker image installed"
        fi        
    fi
}

install_openvino_notebook_docker(){

    echo -e "\n# Git clone OpenVINO™ notebooks"
    if [ ! -d "./openvino_notebooks" ]; then
        git clone https://github.com/openvinotoolkit/openvino_notebooks.git
    else
        echo "./openvino_notebooks already exists"
    fi

    echo -e "\n# Build OpenVINO™ notebook docker image"
    if ! docker images | grep openvino_notebook; then
        docker run -u root -t -d --rm --name temp_notebooks \
        -v /usr/share/keyrings/intel-graphics.gpg:/usr/share/keyrings/intel-graphics.gpg \
        -v "${PWD}":/mnt openvino/ubuntu24_dev:latest
        docker exec -u root temp_notebooks bash -c "apt update && apt install -y wget ffmpeg"
        docker exec -u root temp_notebooks bash -c "cd /mnt/openvino_notebooks; pip install wheel setuptools; pip install -r requirements.txt"
        docker commit temp_notebooks openvino_notebook/ubuntu24_dev:latest
        docker stop temp_notebooks
    else
        echo "$S_VALID OpenVINO™ notebook docker image already installed"
    fi
}

setup() {
    verify_dependencies
    setup_docker
    install_openvino_docker
    install_openvino_notebook_docker

    echo -e "\n# Status"
    echo "$S_VALID OpenVINO™ use case Installed"
}

setup
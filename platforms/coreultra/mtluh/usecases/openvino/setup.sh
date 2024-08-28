#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0 

set -e

# symbol
S_VALID="✓"
CURRENT_DIRECTORY=$(pwd)

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

install_openvino_docker(){

    echo -e "\n# Install OpenVINO™ docker image"
    if ! docker images | grep openvino/ubuntu22_dev; then
        docker pull openvino/ubuntu22_dev:latest
        docker tag openvino/ubuntu22_dev:latest openvino/ubuntu22_dev:devkit
    else
        echo "$S_VALID OpenVINO™ docker image already installed"
    fi

    echo -e "\n# Build OpenVINO™ with NPU docker image"
    if ! docker images | grep openvino_npu/ubuntu22_dev; then
        docker build --progress=plain --no-cache -t openvino_npu/ubuntu22_dev:latest -f Dockerfile .
        docker rmi openvino/ubuntu22_dev:devkit openvino/ubuntu22_dev:latest
    else
        echo "$S_VALID OpenVINO™ with NPU docker image already installed"
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
        docker run -t -d --rm --name temp_notebooks -v "${CURRENT_DIRECTORY}":/mnt openvino_npu/ubuntu22_dev:latest
        docker exec -u root temp_notebooks bash -c "apt update && apt install -y wget ffmpeg"
        docker exec -u root temp_notebooks bash -c "cd /mnt; ./npu_container.sh"
        docker exec -u root temp_notebooks bash -c "cd /mnt/openvino_notebooks; pip install wheel setuptools; pip install -r requirements.txt"
        docker commit temp_notebooks openvino_notebook/ubuntu22_dev:latest
        docker stop temp_notebooks
    else
        echo "$S_VALID OpenVINO™ notebook docker image already installed"
    fi
}

setup() {
    verify_dependencies
    install_openvino_docker
    install_openvino_notebook_docker

    echo -e "\n# Status"
    echo "$S_VALID OpenVINO™ use case Installed"
}

setup
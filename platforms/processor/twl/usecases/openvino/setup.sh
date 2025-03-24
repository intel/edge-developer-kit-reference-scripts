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

install_openvino_docker(){

    echo -e "\n# Install OpenVINO™ Runtime docker image"
    if ! docker images | grep openvino/ubuntu24_dev; then
        docker pull openvino/ubuntu24_dev:latest
    else
        echo "$S_VALID OpenVINO™ Runtime docker image already installed"
    fi

    echo -e "\n# Install GPU driver in OpenVINO™ Runtime docker image"
    if ! docker images | grep openvino_igpu/ubuntu24_dev; then
        if docker ps | grep openvino_install_gpu; then
            docker stop openvino_install_gpu
            sleep 5
            docker rm openvino_install_gpu
        fi

        docker run -u root -t -d --rm --name openvino_install_gpu \
        -v /usr/share/keyrings/intel-graphics.gpg:/usr/share/keyrings/intel-graphics.gpg \
        -v /etc/environment:/etc/environment \
        -v /etc/group:/etc/group \
        --device=/dev/dri:/dev/dri \
        --group-add="$(stat -c "%g" /dev/dri/render* | head -n 1)" \
        -v /usr/bin:/usr/bin \
        -v "${PWD}":/data/workspace \
        -w /data/workspace openvino/ubuntu24_dev:latest
        
        docker exec openvino_install_gpu bash -c "./install_gpu.sh"

        echo -e "\n# Create OpenVINO™ Runtime docker image with dGPU drivers" 
        docker commit openvino_install_gpu openvino_igpu/ubuntu24_dev:latest
        docker stop openvino_install_gpu
        sleep 5
        docker rmi openvino/ubuntu24_dev

        echo "$S_VALID OpenVINO™ Runtime docker image with dGPU driver installed"
    else
        echo "$S_VALID OpenVINO™ Runtime docker image with dGPU driver already installed"
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
        -v "${PWD}":/mnt openvino_igpu/ubuntu24_dev:latest
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
    install_openvino_docker
    install_openvino_notebook_docker

    echo -e "\n# Status"
    echo "$S_VALID OpenVINO™ use case Installed"
}

setup
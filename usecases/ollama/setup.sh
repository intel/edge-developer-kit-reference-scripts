#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0 

set -e

# BKC
OS_ID="ubuntu"
OS_VERSION="22.04"
ONEAPI_VERSION="2024.1"

OLLAMA_DIR="./ollama_dir"
ENV_DIR="./llm_env"

# symbol
S_VALID="✓"
#S_INVALID="✗"

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

verify_platform() {
    echo -e "\n# Verifying platform"
    CPU_MODEL=$(< /proc/cpuinfo grep -m1 "model name" | cut -d: -f2 | sed 's/^[ \t]*//')
    echo "- CPU model: $CPU_MODEL"
}

verify_gpu() {
    echo -e "\n# Verifying GPU"
    DGPU="$(lspci | grep -E 'VGA|DISPLAY' | grep Intel -c)"

    if [ "$DGPU" -ge 1 ]; then
        if [ ! -e "/dev/dri" ]; then
            IGPU=1
        else
            IGPU="$(find /dev/dri -maxdepth 1 -type c -name 'renderD128*' | wc -l)"
        fi
    fi
    if [ -e "/dev/dri" ]; then
        IGPU="$(find /dev/dri -maxdepth 1 -type c -name 'renderD128*' | wc -l)"
    fi

    if [ "$DGPU" -ge 2 ]; then
        GPU_STAT_LABEL="- iGPU\n- dGPU"
    else
        if [ "$IGPU" -lt 1 ]; then
            GPU_STAT_LABEL="- n/a"
        else
            GPU_STAT_LABEL="- iGPU (default)"   
        fi
    fi
    echo -e "$GPU_STAT_LABEL"
}

verify_drivers() {
    echo -e "\n# Verifying drivers"

    if [ -z "$(clinfo | grep 'Driver Version' | awk '{print $NF}')" ]; then
        echo "Error: Failed to configure GPU driver, ensure that GPU driver is properly installed."
        exit 1
    fi
    GPU_DRIVER_VERSION="$(clinfo | grep 'Device Name\|Driver Version' | head -n4)"
    echo -e "$S_VALID Intel GPU Drivers:\n$GPU_DRIVER_VERSION"
}

verify_os() {
    echo -e "\n# Verifying operating system"
    if [ ! -e /etc/os-release ]; then
        echo "Error: /etc/os-release file not found"
        exit 1
    fi
    CURRENT_OS_ID=$(grep -E '^ID=' /etc/os-release | cut -d'=' -f2- | tr -d '"')
    CURRENT_OS_VERSION=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d'=' -f2- | tr -d '"')
    if [ "$OS_ID" != "$CURRENT_OS_ID" ] || [ "$OS_VERSION" != "$CURRENT_OS_VERSION" ]; then
        echo "Error: OS is not supported. Please make sure $OS_ID $OS_VERSION is installed"
        exit 1
    fi
    echo "$S_VALID OS version: $CURRENT_OS_ID $CURRENT_OS_VERSION"
}

verify_ppa_deadsnakes_repo(){
    if [ ! -e /etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-jammy.list ]; then
        echo "Adding Deadsnakes PPA Repository"
        sudo add-apt-repository ppa:deadsnakes/ppa -y
        sudo -E apt update
    fi
}

verify_python3.11_installation(){
    echo -e "\n# Verifying Python 3.11 Installation"
    if ! command -v python3.11 &> /dev/null; then
        echo "Installing Python 3.11"
        verify_ppa_deadsnakes_repo
        PYTHON_PACKAGES=(
            python3.11
            python3.11-venv
        )
        install_packages "${PYTHON_PACKAGES[@]}"        
    fi

    CURRENT_PYTHON_VERSION=$(python3.11 --version | cut -d' ' -f2)
    echo "$S_VALID Python3.11 version: $CURRENT_PYTHON_VERSION"
}

verify_llm_dependencies(){
    echo -e "\n# Verifying LLM Dependencies"
    
    [ ! -d "$ENV_DIR" ] && python3.11 -m venv "$ENV_DIR"

    # shellcheck source=/dev/null  
    source "$ENV_DIR/bin/activate"

    # Install dependencies
    if pip install --upgrade pip && \
    pip install --pre --upgrade 'ipex-llm[cpp]' && \
    pip install --upgrade open-webui && \
    install_packages "curl"
    then
        echo "All dependencies were installed successfully"
    else
        echo "Failed to install dependencies"
        exit 1
    fi
}

verify_ollama_installation(){
    echo -e "\n# Verifying Ollama Installation"
    
    if [ ! -d "$OLLAMA_DIR" ]; then
        mkdir -p "$OLLAMA_DIR" && cd "$OLLAMA_DIR"
        init-ollama
    else
        echo "Ollama folder already exists at $OLLAMA_DIR"
        if [ -z "$(ls "$OLLAMA_DIR")" ]; then
            echo "Ollama folder is empty. Initializing Ollama..."
            cd "$OLLAMA_DIR"
            init-ollama
        else
            echo "Ollama is already Initialized."
        fi
    fi
}

verify_oneapi_repo(){
    if [ ! -e /etc/apt/sources.list.d/oneAPI.list ]; then
        ONEAPI_PACKAGE=(
            gpg-agent
            wget
        )
        install_packages "${ONEAPI_PACKAGE[@]}" 
        wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
        sudo -E apt update
    fi
}

verify_oneapi(){
    echo -e "\n# Verifying Intel oneAPI version"
    if ! command source /opt/intel/oneapi/$ONEAPI_VERSION/oneapi-vars.sh --force &> /dev/null; then
        echo "Installing Intel oneAPI Base Toolkit"
        verify_oneapi_repo
        install_packages "intel-basekit-$ONEAPI_VERSION"
    fi
    echo "$S_VALID Intel oneAPI Base Toolkit Installed"    
}


setup() {

    verify_platform
    verify_gpu
    verify_os
    verify_drivers

    verify_oneapi

    verify_python3.11_installation
    verify_llm_dependencies
    verify_ollama_installation

    echo -e "\n# Status"
    echo "$S_VALID Setup Installed"
    
}

setup
#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0 

set -e

# BKC
OS_ID="ubuntu"
OS_VERSION="24.04"
KERNEL_PACKAGE_NAME="linux-image-6.11.0-1007-oem"

# symbol
S_VALID="✓"
#S_INVALID="✗"

# verify current user
if [ ! "$EUID" -eq 0 ]; then
    echo "Please run with sudo or root user"
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
        apt update
        apt install -y "${PACKAGES[@]}"
    fi
}

verify_kernel_package() {
    echo -e "Verifying kernel package"
    LATEST_KERNEL_VERSION=$(apt-cache madison $KERNEL_PACKAGE_NAME | awk '{print $3}' | sort -V | tail -n 1 | tr '-' '.')
    CURRENT_KERNEL_VERSION_INSTALLED=$(dpkg -l | grep "^ii.*$KERNEL_PACKAGE_NAME" | awk '{print $3}' | sort -V | tail -n 1 | tr '-' '.')
    LATEST_KERNEL_INSTALLED=$(dpkg -l | grep "^ii.*$KERNEL_PACKAGE_NAME" | grep -E "${LATEST_KERNEL_VERSION}[^ ]*" | awk '{print $3}' | tr '-' '.')

    # extract flavour name
    KERNEL_FLAVOUR=""
    if [[ $KERNEL_PACKAGE_NAME == *"generic"* ]]; then
        KERNEL_FLAVOUR="generic"
    elif [[ $KERNEL_PACKAGE_NAME == *"oem"* ]]; then
        KERNEL_FLAVOUR="oem"
    elif [[ $KERNEL_PACKAGE_NAME == *"intel-iotg"* ]]; then
        KERNEL_FLAVOUR="intel-iotg"
    fi

    if [ -z "$LATEST_KERNEL_INSTALLED" ]; then
        echo "Installing latest '${KERNEL_PACKAGE_NAME}' kernel"
        KERNEL_PACKAGES=("${KERNEL_PACKAGE_NAME}")
        install_packages "${KERNEL_PACKAGES[@]}"
    fi
    if [[ ! "$LATEST_KERNEL_VERSION" == *"$CURRENT_KERNEL_VERSION_REVISION"* ]]; then
        if dpkg -l | grep -q 'linux-image.*generic$' && [ "$KERNEL_FLAVOUR" != "generic" ]; then
            echo "Removing generic kernel"
            apt remove -y --auto-remove linux-image-generic-hwe-$OS_VERSION
            DEBIAN_FRONTEND=noninteractive apt purge -y 'linux-image-*-generic'
        elif dpkg -l | grep -q 'linux-image.*iotg$' && [ "$KERNEL_FLAVOUR" != "intel-iotg" ]; then
            echo "Removing Intel IoT kernel"
            apt remove -y --auto-remove linux-image-intel-iotg
            DEBIAN_FRONTEND=noninteractive apt purge -y 'linux-image-*-iotg'
        elif dpkg -l | grep -q 'linux-image.*oem$' && [ "$KERNEL_FLAVOUR" != "oem" ]; then
            echo "Removing OEM kernel"
            DEBIAN_FRONTEND=noninteractive apt purge -y 'linux-image-*-oem'
        fi
        echo "Running kernel version: $CURRENT_KERNEL_VERSION_REVISION"
        echo "Installed kernel version: $CURRENT_KERNEL_VERSION_INSTALLED"
    fi
}

verify_intel_gpu_package_repo(){
    if [ ! -e /etc/apt/sources.list.d/intel-gpu-jammy.list ]; then
        echo "Adding Intel GPU repository"
        wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
            gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg
        echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu noble client" | \
            tee /etc/apt/sources.list.d/intel-gpu-noble.list
        apt update
    fi
}

verify_dgpu_driver(){
    echo -e "Verifying dGPU driver"

    verify_intel_gpu_package_repo
    DGPU_PACKAGES=(
         libze-intel-gpu1 
         libze1 
         intel-opencl-icd 
         clinfo 
         intel-gsc
    )
    install_packages "${DGPU_PACKAGES[@]}"
    if ! id -nG "$USER" | grep -q -w '\<video\>'; then
        echo "Adding current user to 'video' group"
        usermod -aG video "$USER"
    fi
    if ! id -nG "$USER" | grep -q '\<render\>'; then
        echo "Adding current user to 'render' group"
        usermod -aG render "$USER"
    fi

}
# verify platform
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

# verify kernel
verify_kernel() {
    echo -e "\n# Verifying kernel version"
    CURRENT_KERNEL_VERSION=$(uname -r | cut -d'-' -f1)
    CURRENT_KERNEL_REVISION=$(uname -r | cut -d'-' -f2)
    CURRENT_KERNEL_VERSION_REVISION="$CURRENT_KERNEL_VERSION.$CURRENT_KERNEL_REVISION"
    
    if [[ -n "$KERNEL_PACKAGE_NAME" ]]; then
        verify_kernel_package
    else
        echo "Error: Custom build kernel not yet supported."
        exit 1
    fi
    echo "$S_VALID Kernel version: $(uname -r)"
}

# verify drivers
verify_drivers() {
    echo -e "\n# Verifying drivers"
    verify_dgpu_driver

    if [ -z "$(clinfo | grep 'Driver Version' | awk '{print $NF}')" ]; then
        echo "Error: Failed to configure GPU driver"
        exit 1
    fi

    echo -e "Upgrading packages"
    apt dist-upgrade -y
}

setup() {
    # verify_dependencies
    verify_platform
    verify_gpu

    verify_os
    verify_drivers
    verify_kernel

    GPU_DRIVER_VERSION="$(clinfo | grep 'Device Name\|Driver Version' | head -n4)"
    echo -e "$S_VALID Intel GPU Drivers:\n$GPU_DRIVER_VERSION"

    echo -e "\n# Status"
    echo "$S_VALID Platform configured"
    echo "System reboot is required."
}

setup

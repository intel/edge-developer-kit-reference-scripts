#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0 

set -e

# BKC
OS_ID="ubuntu"
OS_VERSION="22.04"
KERNEL_VERSION="6.5.0"
KERNEL_VERSION_GREATER=1
GPU_DRIVER_VERSION="n/a"

# symbol
S_VALID="✓"
S_INVALID="✗"

# verify current user
if [ "$EUID" -eq 0 ]; then
    echo "Must not run with sudo or root user"
    exit 1
fi

install_packages(){
    local PACKAGES=("$@")
    local INSTALL_REQUIRED=0
    for PACKAGE in "${PACKAGES[@]}"; do
        if ! dpkg -s "$PACKAGE" &> /dev/null; then
            echo "$PACKAGE is not installed."
            INSTALL_REQUIRED=1
        fi
    done
    if [ $INSTALL_REQUIRED -eq 1 ]; then
        sudo -E apt update
        sudo -E apt install -y "${PACKAGES[@]}"
    fi
}

verify_dependencies(){
    echo -e "# Verifying dependencies"
    DEPENDENCIES_PACKAGES=(
        git
        clinfo
        curl
        wget
        gpg-agent
    )
    install_packages "${DEPENDENCIES_PACKAGES[@]}"
    echo "$S_VALID Dependencies installed";
}


verify_latest_hwe_kernel(){
    echo -e "Verifying latest HWE kernel"
    LATEST_KERNEL_INSTALLED=$(apt list --installed 2>/dev/null | grep linux-image-generic-hwe | awk -F/ '{print $2}')
    HWE_KERNEL_VERSION_INSTALLED=$(apt list --installed linux-image-generic-hwe-$OS_VERSION 2>/dev/null | awk '/linux-image-generic-hwe/ {print $2}' | cut -d'-' -f4 | awk -F'.' '{print $1"."$2"."$3}' | sort -V | tail -n 1)
    HWE_KERNEL_VERSION_LATEST=$(apt list -a linux-image-generic-hwe-$OS_VERSION 2>/dev/null | grep -oE "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)" | sort -V | tail -n 1 | awk -F'.' '{print $1"."$2"."$3}')

    if [ -z "$LATEST_KERNEL_INSTALLED" ]; then
        echo "Installing latest HWE kernel"
        HWE_KERNEL_PACKAGES=(linux-generic-hwe-$OS_VERSION)
        install_packages "${HWE_KERNEL_PACKAGES[@]}"
        echo "System reboot is required. Re-run the script after reboot"
        exit 0
    fi
    if [ "$CURRENT_KERNEL_VERSION" != "$HWE_KERNEL_VERSION_LATEST" ]; then
        if [ "$HWE_KERNEL_VERSION_INSTALLED" != "$HWE_KERNEL_VERSION_LATEST" ]; then
            echo "Upgrading latest HWE kernel"
            HWE_KERNEL_PACKAGES=(linux-generic-hwe-$OS_VERSION)
            install_packages "${HWE_KERNEL_PACKAGES[@]}"
        else
            echo "Installed HWE kernel version: $HWE_KERNEL_VERSION_INSTALLED"
            echo "Running kernel version: $CURRENT_KERNEL_VERSION"
        fi
        echo "System reboot is required. Re-run the script after reboot"
        exit 0
    fi
}

verify_intel_gpu_package_repo(){
    if [ ! -e /etc/apt/sources.list.d/intel-gpu-jammy.list ]; then
        echo "Adding Intel GPU repository"
        wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | \
            sudo gpg --dearmor --yes --output /usr/share/keyrings/intel-graphics.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy/production/2328 unified" | \
            sudo tee /etc/apt/sources.list.d/intel-gpu-jammy.list
        sudo apt update
    fi
}

verify_igpu_driver(){
    echo -e "Verifying iGPU driver"
        
    # verify compute and media runtimes
    if [ -z "$(clinfo | grep 'Driver Version' | awk '{print $NF}')" ]; then
        verify_intel_gpu_package_repo
        IGPU_PACKAGES=(
            intel-opencl-icd
            intel-level-zero-gpu
            level-zero
            intel-media-va-driver-non-free
            libmfx1
            libmfxgen1
            libvpl2
            libegl-mesa0
            libegl1-mesa
            libegl1-mesa-dev
            libgbm1
            libgl1-mesa-dev
            libgl1-mesa-dri
            libglapi-mesa
            libgles2-mesa-dev
            libglx-mesa0
            libigdgmm12
            libxatracker2
            mesa-va-drivers
            mesa-vdpau-drivers
            mesa-vulkan-drivers
            vainfo
            hwinfo
        )
        install_packages "${IGPU_PACKAGES[@]}"
        if ! id -nG "$USER" | grep -q -w '\<video\>'; then
            echo "Adding current user to 'video' group"
            sudo usermod -aG video $USER
        fi
        if ! id -nG "$USER" | grep -q '\<render\>'; then
            echo "Adding current user to 'render' group"
            sudo usermod -aG render $USER
        fi
    fi

}

# verify platform
verify_platform() {
    echo -e "\n# Verifying platform"
    CPU_MODEL=$(cat /proc/cpuinfo | grep -m1 "model name" | cut -d: -f2 | sed 's/^[ \t]*//')
    echo "- CPU model: $CPU_MODEL"
}

verify_gpu() {
    echo -e "\n# Verifying GPU"
    DGPU="$(lspci | grep VGA | grep Intel | wc -l)"

    if [ "$DGPU" -ge 1 ]; then
        if [ ! -e "/dev/dri" ]; then
            IGPU=1
        else
            IGPU="$(ls /dev/dri | grep 'renderD128' | wc -l)"
        fi
    fi
    if [ -e "/dev/dri" ]; then
        IGPU="$(ls /dev/dri | grep 'renderD128' | wc -l)"
    fi

    if [ $DGPU -ge 2 ]; then
        GPU_STAT_LABEL="- iGPU\n-dGPU (default)"
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
    if [ $KERNEL_VERSION_GREATER -eq 1 ]; then
        if [[ "$(printf '%s\n' "$KERNEL_VERSION" "$CURRENT_KERNEL_VERSION" | sort -V | head -n1)" != "$KERNEL_VERSION" ]]; then
            verify_latest_hwe_kernel
        fi
    else
        if [ "$KERNEL_VERSION" != "$CURRENT_KERNEL_VERSION" ]; then
            verify_latest_hwe_kernel
        fi
    fi
    echo "$S_VALID Kernel version: $CURRENT_KERNEL_VERSION"
}

# verify drivers
verify_drivers() {
    echo -e "\n# Verifying drivers"
    if [ $DGPU -ge 2 ]; then
        echo "Error: dGPU driver is not supported"
        exit 1
    else
        verify_igpu_driver        
    fi
    if [ -z "$(clinfo | grep 'Driver Version' | awk '{print $NF}')" ]; then
        echo "Error: Failed to configure GPU driver"
        exit 1
    fi
    GPU_DRIVER_VERSION="$(clinfo | grep 'Driver Version' | awk '{print $NF}')"
    echo "$S_VALID Intel GPU Drivers: $GPU_DRIVER_VERSION"
}

setup() {
    verify_dependencies
    verify_platform
    verify_gpu

    verify_os
    verify_kernel
    verify_drivers

    echo -e "\n# Status"
    echo "$S_VALID Platform configured"
}

setup

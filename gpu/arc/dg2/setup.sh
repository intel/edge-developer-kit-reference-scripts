#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0 

set -e

# BKC
OS_ID="ubuntu"
OS_VERSION="24.04"

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

verify_dependencies(){
    echo -e "# Verifying dependencies"
    DEPENDENCIES_PACKAGES=(
        curl
        wget
        gpg-agent
        software-properties-common
    )
    install_packages "${DEPENDENCIES_PACKAGES[@]}"
    echo "$S_VALID Dependencies installed";
}

verify_intel_gpu_package_repo(){
    if [ ! -e /etc/apt/sources.list.d/kobuk-team-ubuntu-intel-graphics-noble.sources ]; then
        echo "Adding Intel GPU repository"
        add-apt-repository -y ppa:kobuk-team/intel-graphics
        apt update
    fi
}        

verify_dgpu_driver(){
    echo -e "Verifying dGPU driver"

    verify_intel_gpu_package_repo
    DGPU_PACKAGES=(
        libze-intel-gpu1 
        libze1 
        intel-metrics-discovery 
        intel-opencl-icd 
        clinfo 
        intel-gsc
        intel-media-va-driver-non-free 
        libmfx-gen1 
        libvpl2 
        libvpl-tools 
        libva-glx2 
        va-driver-all 
        vainfo
    )
    install_packages "${DGPU_PACKAGES[@]}"
    
    # $USER here is root
    if ! id -nG "$USER" | grep -q -w '\<video\>'; then
        echo "Adding current user ($USER) to 'video' group"
        usermod -aG video "$USER"
    fi
    if ! id -nG "$USER" | grep -q '\<render\>'; then
        echo "Adding current user ($USER) to 'render' group"
        usermod -aG render "$USER"
    fi

    # Get the native user who invoked sudo
    NATIVE_USER="$(logname)"
        
    if ! id -nG "$NATIVE_USER" | grep -q -w '\<video\>'; then
        echo "Adding native user ($NATIVE_USER) to 'video' group"
        usermod -aG video "$NATIVE_USER"
    fi
    if ! id -nG "$NATIVE_USER" | grep -q '\<render\>'; then
        echo "Adding native user ($NATIVE_USER) to 'render' group"
        usermod -aG render "$NATIVE_USER"
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


# verify drivers
verify_drivers() {
    echo -e "\n# Verifying drivers"
    verify_dgpu_driver

    if [ -z "$(clinfo | grep 'Driver Version' | awk '{print $NF}')" ]; then
        echo "Error: Failed to configure GPU driver"
        exit 1
    fi
    GPU_DRIVER_VERSION="$(clinfo | grep 'Device Name\|Driver Version' | head -n4)"
    echo -e "$S_VALID Intel GPU Drivers:\n$GPU_DRIVER_VERSION"
}
verify_kernel() {
    echo -e "\n# Verifying kernel version"
    KERNEL_VERSION=$(uname -r | cut -d'-' -f1)
    if [[ "$KERNEL_VERSION" == 6.8* ]]; then
        echo "Kernel version is 6.8. Running dist-upgrade and reboot required."
        apt update
        apt dist-upgrade -y
        echo "System reboot is required. Re-run the script after reboot"
        exit 0
    else
        echo "$S_VALID Kernel version: $KERNEL_VERSION"
    fi
}
setup() {
    verify_kernel
    verify_dependencies
    verify_platform
    verify_gpu

    verify_os
    verify_drivers

    echo -e "\n# Status"
    echo "$S_VALID Platform configured"
    echo "Please log out and log back in to take effect."
}

setup

#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0 

set -e

# BKC
OS_ID="ubuntu"
OS_VERSION="22.04"
KERNEL_VERSION="6.6-intel"

# symbol
S_VALID="✓"
#S_INVALID="✗"

# verify current user
if [ ! "$EUID" -eq 0 ]; then
    echo "Please run with sudo or root user"
    exit 1
fi

# resolve scripts directory
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" 
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

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
        git
        curl
        wget
        clinfo
    )
    install_packages "${DEPENDENCIES_PACKAGES[@]}"
    echo "$S_VALID Dependencies installed"
}

verify_intel_gpu_package_repo(){
    if [ ! -e /etc/apt/sources.list.d/intel-gpu-jammy.list ]; then
        echo "Adding Intel GPU repository"
        wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
            gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg
        echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | \
            tee /etc/apt/sources.list.d/intel-gpu-jammy.list
        apt update
    fi
}

verify_igpu_driver(){
    # TODO: verify if same iGPU driver setup can use for dGPU
    echo -e "Verifying iGPU driver"
    
    # verify compute and media runtimes
    if [ -z "$(clinfo | grep 'Driver Version' | awk '{print $NF}')" ]; then
        verify_intel_gpu_package_repo
        IGPU_PACKAGES=(
            intel-opencl-icd
            intel-level-zero-gpu
            libze1
            clinfo
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

        # $USER here is root
        if ! id -nG "$USER" | grep -q -w '\<video\>'; then
            echo "Adding $USER to 'video' group"
            usermod -aG video "$USER"
        fi
        if ! id -nG "$USER" | grep -q '\<render\>'; then
            echo "Adding $USER to 'render' group"
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

    fi
}

install_kernel_overlay() {
    echo -e "## Install User Space Components"
    apt -y update
    apt -y upgrade

    echo -e "### Add download link into /etc/apt/sources.list.d/intel-asl.list"
    touch /etc/apt/sources.list.d/intel-asl.list
    echo -e "deb https://download.01.org/intel-linux-overlay/ubuntu jammy main non-free multimedia kernels\n\
    deb-src https://download.01.org/intel-linux-overlay/ubuntu jammy main non-free multimedia kernels" | tee /etc/apt/sources.list.d/intel-asl.list

    echo -e "### Download GPG key to /etc/apt/trusted.gpg.d/asladln.gpg"
    wget https://download.01.org/intel-linux-overlay/ubuntu/E6FA98203588250569758E97D176E3162086EE4C.gpg -O /etc/apt/trusted.gpg.d/asladln.gpg

    echo -e "### Set the preferred list in /etc/apt/preferences.d/intel-asl"
    touch /etc/apt/preferences.d/intel-asl
    echo -e "Package: *\n\
    Pin: release o=intel-iot-linux-overlay\n\
    Pin-Priority: 2000" | tee /etc/apt/preferences.d/intel-asl

    echo -e "## Install Kernel Overlay"
    apt -y update
    apt -y install linux-image-6.6-intel
    apt -y install linux-headers-6.6-intel
    apt -y install linux-libc-dev

    echo -e "## Update grub"
    sed -i 's/^GRUB_DEFAULT=.*$/GRUB_DEFAULT="Advanced options for Ubuntu>Ubuntu, with Linux 6.6-intel"/' /etc/default/grub
    update-grub

    echo "System reboot is required. Re-run the script after reboot"
    exit 0
}

verify_platform() {
    echo -e "\n# Verifying platform"
    CPU_MODEL=$(< /proc/cpuinfo grep -m1 "model name" | cut -d: -f2 | sed 's/^[ \t]*//')
    echo "- CPU model: $CPU_MODEL"
}

verify_gpu() {
    echo -e "\n# Verifying GPU"
    DGPU="$(lspci | grep VGA | grep Intel -c)"

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
        GPU_STAT_LABEL="- iGPU\n-dGPU (default)"
        echo kern_upgrade_dgpu
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

verify_kernel() {
    echo -e "\n# Verifying kernel version"
    CURRENT_KERNEL_VERSION=$(uname -r | cut -d'-' -f1)
    CURRENT_KERNEL_REVISION=$(uname -r | cut -d'-' -f2)
    CURRENT_KERNEL_VERSION_REVISION="$CURRENT_KERNEL_VERSION-$CURRENT_KERNEL_REVISION"

    if [ "$CURRENT_KERNEL_VERSION_REVISION" != "$KERNEL_VERSION" ]; then
        echo -e "Current Kernel: $CURRENT_KERNEL_VERSION_REVISION"
        echo -e "To be install: $KERNEL_VERSION"
        install_kernel_overlay
    elif [ "$CURRENT_KERNEL_VERSION_REVISION" == "$KERNEL_VERSION" ]; then
        echo -e "Current Kernel: $CURRENT_KERNEL_VERSION_REVISION"
        echo -e "Kernel Updated"
    else
        # TODO: option to install kernel via verify_custom_build_kernel
        echo "Error: Custom build kernel not yet supported."
        exit 1
    fi
    echo "$S_VALID Kernel version: $(uname -r)"
}

verify_drivers() {
    echo -e "\n# Verifying drivers"
    if [ "$DGPU" -ge 2 ]; then
        # TODO: verify_dgpu_driver for supported platform
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

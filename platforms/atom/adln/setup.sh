#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0 

set -e

# BKC
OS_ID="ubuntu"
OS_VERSION="22.04"
# KERNEL_PACKAGE_NAME="linux-image-generic-hwe-22.04"
# KERNEL_PACKAGE_NAME="linux-image-oem-22.04d"
# KERNEL_PACKAGE_NAME="linux-image-intel-iotg"
# KERNEL_PACKAGE_NAME="linux-image-6.5.0-1009-oem"
KERNEL_PACKAGE_NAME="linux-image-6.1.80--000"

# symbol
S_VALID="✓"
#S_INVALID="✗"

# verify current user
if [ "$EUID" -eq 0 ]; then
    echo "Must not run with sudo or root user"
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
        sudo -E apt update
        sudo -E apt install -y "${PACKAGES[@]}"
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
            sudo gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy/production/2328 unified" | \
            sudo tee /etc/apt/sources.list.d/intel-gpu-jammy.list
        sudo -E apt update
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
            sudo usermod -aG video "$USER"
        fi
        if ! id -nG "$USER" | grep -q '\<render\>'; then
            echo "Adding current user to 'render' group"
            sudo usermod -aG render "$USER"
        fi
    fi
}

verify_kernel_package() {
    echo -e "Checking kernel version"
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
        build_kernel
    fi
    if [[ ! "$LATEST_KERNEL_VERSION" == *"$CURRENT_KERNEL_VERSION_REVISION"* ]]; then
        if dpkg -l | grep -q 'linux-image.*generic$' && [ "$KERNEL_FLAVOUR" != "generic" ]; then
            echo "Removing generic kernel"
            sudo apt remove -y --auto-remove linux-image-generic-hwe-$OS_VERSION
            sudo DEBIAN_FRONTEND=noninteractive apt purge -y 'linux-image-*-generic'
        elif dpkg -l | grep -q 'linux-image.*iotg$' && [ "$KERNEL_FLAVOUR" != "intel-iotg" ]; then
            echo "Removing Intel IoT kernel"
            sudo apt remove -y --auto-remove linux-image-intel-iotg
            sudo DEBIAN_FRONTEND=noninteractive apt purge -y 'linux-image-*-iotg'
        elif dpkg -l | grep -q 'linux-image.*oem$' && [ "$KERNEL_FLAVOUR" != "oem" ]; then
            echo "Removing OEM kernel"
            sudo DEBIAN_FRONTEND=noninteractive apt purge -y 'linux-image-*-oem'
        fi
        echo "Running kernel version: $CURRENT_KERNEL_VERSION_REVISION"
        echo "Installed kernel version: $CURRENT_KERNEL_VERSION_INSTALLED"
    fi
}

build_kernel(){
    echo -e "Building kernel package"
    # verify and build packages  
    BUILD_KERNEL_PACKAGES=(
        flex 
        bison 
        kernel-wedge 
        gcc 
        libssl-dev 
        libelf-dev 
        quilt 
        liblz4-tool
    )
    install_packages "${BUILD_KERNEL_PACKAGES[@]}"
    echo "Preparing necessary packages to build kernel..."
    if [ ! -d "linux-kernel-overlay" ]; then
        git clone https://github.com/intel/linux-kernel-overlay.git
    fi
    cd linux-kernel-overlay || { echo "linux-kernel-overlay folder not found"; exit 1; }
    if ! ls ./*.deb 1> /dev/null 2>&1; then
        git checkout tags/lts-overlay-v6.1.80-ubuntu-240430T084807Z
        echo "Building kernel"
        echo "This process will take around 1 hour. Please keep the system turned on."
        ./build.sh
    fi
    replace_kernel
}

replace_kernel(){
    echo -e "Replacing kernel..."
    sudo dpkg -i linux-headers-6.1.80--000_6.1.80-0_amd64.deb
    sudo dpkg -i linux-image-6.1.80--000_6.1.80-0_amd64.deb
    sudo dpkg -i linux-libc-dev_6.1.80-0_amd64.deb
    sudo update-grub
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
    CURRENT_KERNEL_REVISION=$(uname -r | rev | cut -d'-' -f1 | rev)
    CURRENT_KERNEL_VERSION_REVISION="$CURRENT_KERNEL_VERSION.$CURRENT_KERNEL_REVISION"
    
    if [[ -n "$KERNEL_PACKAGE_NAME" ]]; then
        verify_kernel_package
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

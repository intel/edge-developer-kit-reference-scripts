#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -e

# BKC
OS_ID="ubuntu"
OS_VERSION="22.04"
KERNEL_PACKAGE_NAME="linux-image-6.5.0-1009-oem"

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

verify_dependencies(){
    echo -e "# Verifying dependencies"
    DEPENDENCIES_PACKAGES=(
        git
        clinfo
        curl
        wget
        gpg-agent
        libtbb12
    )
    install_packages "${DEPENDENCIES_PACKAGES[@]}"
    echo "$S_VALID Dependencies installed"
}

verify_intel_gpu_package_repo(){
    if [ ! -e /etc/apt/sources.list.d/intel-gpu-jammy.list ]; then
        echo "Adding Intel GPU repository"
        wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | \
            sudo gpg --dearmor --yes --output /usr/share/keyrings/intel-graphics.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | \
            sudo tee /etc/apt/sources.list.d/intel-gpu-jammy.list
        sudo apt update
    fi

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
        echo "System reboot is required. Re-run the script after reboot"
        exit 0
    fi
}

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

verify_igpu_driver(){
    echo -e "Verifying iGPU driver"

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
	    va-driver-all
	    vainfo
	    hwinfo
        )
        install_packages "${IGPU_PACKAGES[@]}"
        FIRMWARE=(linux-firmware)
        install_packages "${FIRMWARE[@]}"

        if ! id -nG "$USER" | grep -q -w '\<video\>'; then
            echo "Adding current user to 'video' group"
            sudo usermod -aG video "$USER"
        fi
        if ! id -nG "$USER" | grep -q '\<render\>'; then
            echo "Adding current user to 'render' group"
            sudo usermod -aG render "$USER"
        fi
        echo "System reboot is required. Re-run the script after reboot"
        exit 0
    fi

}

verify_npu_driver(){
    echo -e "Verifying NPU drivers"

    CURRENT_DIR=$(pwd)
    COMPILER_PKG=$(dpkg-query -l "intel-driver-compiler-npu" 2>/dev/null || true)
    LEVEL_ZERO_PKG=$(dpkg-query -l "intel-level-zero-npu" 2>/dev/null || true)

    if [[ -z $COMPILER_PKG || -z $LEVEL_ZERO_PKG ]]; then
        echo -e "NPU Driver is not installed. Proceed installing"
        sudo dpkg --purge --force-remove-reinstreq intel-driver-compiler-npu intel-fw-npu intel-level-zero-npu level-zero
        sudo apt install --fix-broken
        sudo -E apt update

        if [ -d /tmp/npu_temp ];then
            rm -rf /tmp/npu_temp
        else
            mkdir /tmp/npu_temp
            cd /tmp/npu_temp
            wget https://github.com/intel/linux-npu-driver/releases/download/v1.1.0/intel-driver-compiler-npu_1.1.0.20231117-6904283384_ubuntu22.04_amd64.deb
            wget https://github.com/intel/linux-npu-driver/releases/download/v1.1.0/intel-fw-npu_1.1.0.20231117-6904283384_ubuntu22.04_amd64.deb
            wget https://github.com/intel/linux-npu-driver/releases/download/v1.1.0/intel-level-zero-npu_1.1.0.20231117-6904283384_ubuntu22.04_amd64.deb
            wget https://github.com/oneapi-src/level-zero/releases/download/v1.10.0/level-zero_1.10.0+u22.04_amd64.deb

            sudo dpkg -i ./*.deb

            cd ..
            rm -rf npu_temp
            cd "$CURRENT_DIR"
        fi
        sudo chown root:render /dev/accel/accel0
        sudo chmod g+rw /dev/accel/accel0
	sudo bash -c "echo 'SUBSYSTEM==\"accel\", KERNEL==\"accel*\", GROUP=\"render\", MODE=\"0660\"' > /etc/udev/rules.d/10-intel-vpu.rules"
	sudo udevadm control --reload-rules
	sudo udevadm trigger --subsystem-match=accel
    fi

}


verify_drivers(){
    echo -e "\n#Verifying drivers"
    verify_igpu_driver
    if [ -z "$(clinfo | grep 'Driver Version' | awk '{print $NF}')" ]; then
        echo "Error: Failed to configure GPU driver"
        exit 1
    fi
    GPU_DRIVER_VERSION="$(clinfo | grep 'Driver Version' | awk '{print $NF}')"
    echo "$S_VALID Intel GPU Drivers: $GPU_DRIVER_VERSION"

    verify_npu_driver
    
    NPU_DRIVER_VERSION="$(sudo dmesg | grep vpu | awk 'NR==3{ print; }' | awk -F " " '{print $5" "$6" "$7}')"
    echo "$S_VALID Intel NPU Drivers: $NPU_DRIVER_VERSION"
}

setup(){

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

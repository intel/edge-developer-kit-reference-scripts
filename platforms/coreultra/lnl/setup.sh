#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -e

# BKC
OS_ID="ubuntu"
OS_VERSION="24.04"
KERNEL_PACKAGE_NAME="6.11.0-1007-oem"
CURRENT_KERNEL_VERSION=$(uname -r)
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
    if [ ! -e /etc/apt/sources.list.d/intel-gpu-noble.list ]; then
        echo "Adding Intel GPU repository"
        wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
        sudo gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg
        echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu noble client" | \
        sudo tee /etc/apt/sources.list.d/intel-gpu-noble.list
        sudo apt update
        sudo apt-get install -y libze-intel-gpu1 libze1 intel-opencl-icd clinfo intel-gsc
        sudo apt update
        sudo apt -y dist-upgrade

    fi

}

verify_igpu_driver(){
    echo -e "Verifying iGPU driver"

    if [ -z "$(clinfo | grep 'Driver Version' | awk '{print $NF}')" ] && [ ! -e /etc/apt/sources.list.d/intel-gpu-noble.list ]; then
        verify_intel_gpu_package_repo
        IGPU_PACKAGES=(
        libze1
        intel-level-zero-gpu
        intel-opencl-icd
        clinfo
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
    fi
}

verify_compute_runtime(){
    COMPUTE_RUNTIME_VER="24.52.32224.5"
    echo -e "\n# Verifying Intel(R) Compute Runtime drivers"

    echo -e "Install Intel(R) Compute Runtime drivers version: $COMPUTE_RUNTIME_VER"
    if [ -d /tmp/neo_temp ];then
        echo -e "Found existing folder in path /tmp/neo_temp. Removing the folder"
        rm -rf /tmp/neo_temp
    fi
    
    echo -e "Downloading compute runtime packages"
    mkdir -p /tmp/neo_temp
    cd /tmp/neo_temp
    wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.5.6/intel-igc-core-2_2.5.6+18417_amd64.deb
    wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.5.6/intel-igc-opencl-2_2.5.6+18417_amd64.deb
    wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-level-zero-gpu-dbgsym_1.6.32224.5_amd64.ddeb
    wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-level-zero-gpu_1.6.32224.5_amd64.deb
    wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-opencl-icd-dbgsym_24.52.32224.5_amd64.ddeb
    wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-opencl-icd_24.52.32224.5_amd64.deb
    wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/libigdgmm12_22.5.5_amd64.deb
    
    echo -e "Verify sha256 sums for packages"
    wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/ww52.sum
    sha256sum -c ww52.sum

    echo -e "\nInstalling compute runtime as root"
    sudo apt remove -y intel-ocloc libze-intel-gpu1
    sudo dpkg -i ./*.deb 

    cd ..
    echo -e "Cleaning up /tmp/neo_temp folder after installation"
    rm -rf neo_temp
    cd "$CURRENT_DIR"
    
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

verify_npu_driver(){
    echo -e "Verifying NPU drivers"

    CURRENT_DIR=$(pwd)
    COMPILER_PKG=$(dpkg-query -l "intel-driver-compiler-npu" 2>/dev/null || true)
    LEVEL_ZERO_PKG=$(dpkg-query -l "intel-level-zero-npu" 2>/dev/null || true)

    if [[ -z $COMPILER_PKG || -z $LEVEL_ZERO_PKG ]]; then
        echo -e "NPU Driver is not installed. Proceed installing"
        sudo dpkg --purge --force-remove-reinstreq intel-driver-compiler-npu intel-fw-npu intel-level-zero-npu
        sudo apt install --fix-broken
        sudo -E apt update

        if [ -d /tmp/npu_temp ];then
            rm -rf /tmp/npu_temp
        else
            mkdir /tmp/npu_temp
            cd /tmp/npu_temp

            wget https://github.com/intel/linux-npu-driver/releases/download/v1.10.1/intel-driver-compiler-npu_1.10.1.20241220-12430270326_ubuntu24.04_amd64.deb
            wget https://github.com/intel/linux-npu-driver/releases/download/v1.10.1/intel-fw-npu_1.10.1.20241220-12430270326_ubuntu24.04_amd64.deb
            wget https://github.com/intel/linux-npu-driver/releases/download/v1.10.1/intel-level-zero-npu_1.10.1.20241220-12430270326_ubuntu24.04_amd64.deb
            wget https://github.com/oneapi-src/level-zero/releases/download/v1.17.44/level-zero_1.17.44+u22.04_amd64.deb
            
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

verify_kernel() {
    echo -e "\n# Verifying kernel version"
    CURRENT_KERNEL_VERSION=$(uname -r | cut -d'-' -f1)
    CURRENT_KERNEL_REVISION=$(uname -r | cut -d'-' -f2)
    CURRENT_KERNEL_VERSION_REVISION="$CURRENT_KERNEL_VERSION.$CURRENT_KERNEL_REVISION"
    
    if [[ "$KERNEL_PACKAGE_NAME" != $(uname -r) ]]; then
        verify_kernel_package
    else
        echo "$S_VALID Kernel version: $(uname -r)"
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
        if [ "$KERNEL_PACKAGE_NAME" = "6.11.0-1007-oem" ]; then
            echo hello
            sudo apt-get install linux-image-6.11.0-1007-oem -y
            sudo sed -i 's/^GRUB_DEFAULT=.*$/GRUB_DEFAULT="Advanced options for Ubuntu>Ubuntu, with Linux 6.11-intel"/' /etc/default/grub
        else
            echo "${KERNEL_PACKAGE_NAME}"
            install_packages "${KERNEL_PACKAGES[@]}"
        fi
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
    echo "System reboot is required."
    exit 0
}
verify_platform() {
    echo -e "\n# Verifying platform"
    CPU_MODEL=$(< /proc/cpuinfo grep -m1 "model name" | cut -d: -f2 | sed 's/^[ \t]*//')
    echo "- CPU model: $CPU_MODEL"
}

verify_drivers(){
    echo -e "\n#Verifying drivers"
    verify_igpu_driver
    if [ -z "$(clinfo | grep 'Driver Version' | awk '{print $NF}')" ] && [ "$CURRENT_KERNEL_VERSION" = "6.11.0-1007-oem" ]; then
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
    verify_drivers
    verify_kernel
    verify_compute_runtime
    

    echo -e "\n# Status"
    echo "$S_VALID Platform configured"

}

setup

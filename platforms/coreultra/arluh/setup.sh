#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -e

# BKC
OS_ID="ubuntu"
OS_VERSION="24.04"
KERNEL_PACKAGE_NAME="linux-image-6.11.0-1011-oem"
RELEASE_VERSION=${KERNEL_PACKAGE_NAME//linux-image-/}

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
        quilt
        libssl-dev
        kernel-wedge
        liblz4-tool
        libelf-dev
        flex
        bison
    )
    install_packages "${DEPENDENCIES_PACKAGES[@]}"
    echo "$S_VALID Dependencies installed"
}

verify_intel_gpu_package_repo(){
    if [ ! -e /etc/apt/sources.list.d/intel-gpu-jammy.list ]; then
        echo "Adding Intel GPU repository"
        wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
            sudo gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg
        echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu noble client" | \
            sudo tee /etc/apt/sources.list.d/intel-gpu-noble.list
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

    # Download Kernel
    sudo touch /etc/apt/sources.list.d/intel-arl.list
    echo -e "deb https://download.01.org/intel-linux-overlay/ubuntu noble main non-free multimedia kernels\n\
    deb-src https://download.01.org/intel-linux-overlay/ubuntu noble main non-free multimedia kernels" | sudo tee /etc/apt/sources.list.d/intel-arl.list

    echo -e "### Download GPG key to /etc/apt/trusted.gpg.d/asladln.gpg"
    sudo wget https://download.01.org/intel-linux-overlay/ubuntu/E6FA98203588250569758E97D176E3162086EE4C.gpg -O /etc/apt/trusted.gpg.d/arl.gpg

    echo -e "### Set the preferred list in /etc/apt/preferences.d/intel-asl"
    sudo touch /etc/apt/preferences.d/intel-arl
    echo -e "Package: *\n\
    Pin: release o=intel-iot-linux-overlay-noble\n\
    Pin-Priority: 2000" | sudo tee /etc/apt/preferences.d/intel-arl
    
    # Install kernel
    echo -e "## Install Kernel"
    sudo apt -y update
    sudo apt -y install $KERNEL_PACKAGE_NAME

    echo -e "## Update grub"
    sudo sed -i 's|^GRUB_​CMDLINE_​LINUX_​DEFAULT=.*$|GRUB_​CMDLINE_​LINUX_​DEFAULT="quiet splash i915.enable_​guc=3 i915.max_​vfs=7 i915.force_​probe=* udmabuf.list_​limit=8192"|' /etc/default/grub
    sudo sed -i 's/^GRUB_DEFAULT=.*$/GRUB_DEFAULT="Advanced options for Ubuntu>Ubuntu, with Linux 6.11.0-1011-oem"/' /etc/default/grub
    sudo update-grub

    CURRENT_KERNEL_VERSION_INSTALLED=$(uname -r)

    echo "Running kernel version: $CURRENT_KERNEL_VERSION_INSTALLED"
    echo "Installed kernel version: $KERNEL_PACKAGE_NAME"
    echo "System reboot is required. Re-run the script after reboot"
    exit 0
}

verify_kernel() {
    echo -e "\n# Verifying kernel version"
    
    if [[ "$RELEASE_VERSION" != $(uname -r) ]]; then
        verify_kernel_package
    else
        echo "$S_VALID Kernel version: $(uname -r)"
    fi
}

verify_igpu_driver(){
    echo -e "Verifying iGPU driver"

    if [ -z "$(clinfo | grep 'Driver Version' | awk '{print $NF}')" ]; then
        verify_intel_gpu_package_repo
        IGPU_PACKAGES=(
        libze1
        intel-level-zero-gpu
        intel-opencl-icd
        intel-gsc
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
        echo "System reboot is required. Re-run the script after reboot"
        exit 0
    fi
}

verify_compute_runtime(){
    COMPUTE_RUNTIME_VER="24.13.29138.7"
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
    sudo dpkg -i ./*.deb

    cd ..
    echo -e "Cleaning up /tmp/neo_temp folder after installation"
    rm -rf neo_temp
    cd "$CURRENT_DIR"
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
            wget https://github.com/intel/linux-npu-driver/releases/download/v1.5.1/intel-driver-compiler-npu_1.5.1.20240708-9842236399_ubuntu22.04_amd64.deb
            wget https://github.com/intel/linux-npu-driver/releases/download/v1.5.1/intel-fw-npu_1.5.1.20240708-9842236399_ubuntu22.04_amd64.deb
            wget https://github.com/intel/linux-npu-driver/releases/download/v1.5.1/intel-level-zero-npu_1.5.1.20240708-9842236399_ubuntu22.04_amd64.deb
            wget https://github.com/oneapi-src/level-zero/releases/download/v1.17.6/level-zero_1.17.6+u22.04_amd64.deb
            wget https://github.com/oneapi-src/level-zero/releases/download/v1.17.6/level-zero-devel_1.17.6+u22.04_amd64.deb

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
    verify_compute_runtime

    echo -e "\n# Status"
    echo "$S_VALID Platform configured"
}

setup
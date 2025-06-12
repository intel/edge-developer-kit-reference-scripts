#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# BKC
OS_ID="ubuntu"
OS_VERSION="22.04"
KERNEL_PACKAGE_NAME="linux-image-generic"

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
        git
        clinfo
        curl
        wget
        gpg-agent
        hwinfo
    )
    install_packages "${DEPENDENCIES_PACKAGES[@]}"
    echo "$S_VALID Dependencies installed";
}

verify_platform() {
    echo -e "\n# Verifying platform"
    CPU_MODEL=$(< /proc/cpuinfo grep -m1 "model name" | cut -d: -f2 | sed 's/^[ \t]*//')
    echo "- CPU model: $CPU_MODEL"
}

verify_gpu() {
    echo -e "\n# Verifying GPU"
    DGPU="$(lspci -k | grep -E 'VGA|Display' -c)"

    if [ "$DGPU" -ge 1 ]; then
        if [ ! -e "/dev/dri" ]; then
            IGPU=1
        else
            IGPU="$(find /dev/dri -maxdepth 1 -type c -name 'renderD128*' | wc -l )"
        fi
    fi
    if [ -e "/dev/dri" ]; then
        IGPU="$(find /dev/dri -maxdepth 1 -type c -name 'renderD128*' | wc -l)"
    fi

    if [ "$DGPU" -ge 2 ]; then
        GPU_STAT_LABEL="- Flex"
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

verify_kernel_package(){
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
        echo "System reboot is required. Re-run the script after reboot"
        exit 0
    fi
}

verify_kernel(){
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

verify_repo_flex_driver(){

    VERSION_CODENAME=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d'=' -f2)
    if [[ ! " jammy " =~ ${VERSION_CODENAME} ]]; then
        echo "Ubuntu version ${VERSION_CODENAME} not supported"
    else
        wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
        gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu ${VERSION_CODENAME}/lts/2350 unified" | \
        tee /etc/apt/sources.list.d/intel-gpu-"${VERSION_CODENAME}".list
        apt update
        # after add repo only able to install xpu-smi
        xpu_install='xpu-smi'
        install_packages "${xpu_install[@]}"
    fi
}

verify_flex_driver(){
    echo -e "Verifying Flex Drivers"
    verify_repo_flex_driver
    
    output=$(xpu-smi discovery | grep 'No device discovered')

    if [ -n "$output"  ] ; then
        echo "Installing FLEX driver"
        FLEX_PACKAGES=(
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
            linux-headers-"$(uname -r)"
	        flex
            bison
	        intel-fw-gpu
            intel-i915-dkms
        )
        install_packages "${FLEX_PACKAGES[@]}"
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

            echo "System reboot is required. Re-run the script after reboot"
            exit 0
        fi
}

verify_drivers(){
    echo -e "\n#Verifying drivers"
    verify_flex_driver
    output=$(xpu-smi discovery | grep 'No device discovered')
    
    if [ -n "$output" ] ; then
        echo "Error: Failed to configure Flex driver"
        exit 1
    fi
    echo -e "$S_VALID Intel FLEX Drivers:\n$(xpu-smi discovery)"
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

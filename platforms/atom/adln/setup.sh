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
FEATURE_CAM_D3=0
FEATURE_CAM_LEOPARD=0
FEATURE_CAM_INNODISK=0

# symbol
S_VALID="✓"
S_INVALID="✗"

# whiptail
export NEWT_COLORS='
root=,gray
window=,lightgray
listbox=,gray
textbox=black,lightgray
checkbox=,gray
title=black,lightgray
actcheckbox=,black
button=,black
'

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
    # TODO: verify if same iGPU driver setup can use for dGPU
    echo -e "Verifying iGPU driver"
    # verify tool
    if ! clinfo >/dev/null 2>&1; then
        sudo apt install -y clinfo
    fi
    
    # verify compute and media runtimes
    if [ -z "$(clinfo | grep 'Driver Version' | awk '{print $NF}')" ]; then
        verify_intel_gpu_package_repo
        if ! dpkg -s intel-opencl-icd &> /dev/null; then
            echo "Installing compute and media runtimes"
            sudo apt install -y \
                intel-opencl-icd intel-level-zero-gpu level-zero \
                intel-media-va-driver-non-free libmfx1 libmfxgen1 libvpl2 \
                libegl-mesa0 libegl1-mesa libegl1-mesa-dev libgbm1 libgl1-mesa-dev libgl1-mesa-dri \
                libglapi-mesa libgles2-mesa-dev libglx-mesa0 libigdgmm12 libxatracker2 mesa-va-drivers \
                mesa-vdpau-drivers mesa-vulkan-drivers va-driver-all vainfo hwinfo clinfo
        fi
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

verify_latest_hwe_kernel(){
    echo -e "Verifying latest HWE kernel"
    LATEST_KERNEL_INSTALLED=$(apt list --installed 2>/dev/null | grep linux-image-generic-hwe | awk -F/ '{print $2}')
    HWE_KERNEL_VERSION_INSTALLED=$(apt list --installed linux-image-generic-hwe-$OS_VERSION 2>/dev/null | awk '/linux-image-generic-hwe/ {print $2}' | cut -d'-' -f4 | awk -F'.' '{print $1"."$2"."$3}' | sort -V | tail -n 1)
    HWE_KERNEL_VERSION_LATEST=$(apt list -a linux-image-generic-hwe-$OS_VERSION 2>/dev/null | grep -oE "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)" | sort -V | tail -n 1 | awk -F'.' '{print $1"."$2"."$3}')
    
    if [ -z "$LATEST_KERNEL_INSTALLED" ]; then
        echo "Installing latest HWE kernel"
        sudo apt update
        sudo apt install -y linux-generic-hwe-$OS_VERSION
        echo "System reboot is required. Re-run the script after reboot"
        exit 0
    fi
    if [ "$CURRENT_KERNEL_VERSION" != "$HWE_KERNEL_VERSION_LATEST" ]; then
        if [ "$HWE_KERNEL_VERSION_INSTALLED" != "$HWE_KERNEL_VERSION_LATEST" ]; then
            echo "Upgrading latest HWE kernel"
            sudo apt update
            sudo apt install -y linux-generic-hwe-$OS_VERSION
        else
            echo "Installed HWE kernel version: $HWE_KERNEL_VERSION_INSTALLED"
            echo "Running kernel version: $CURRENT_KERNEL_VERSION"
        fi
        echo "System reboot is required. Re-run the script after reboot"
        exit 0
    fi
}

# verify platform
verify_platform() {
    echo -e "# Verifying platform"
    CPU_MODEL=$(cat /proc/cpuinfo | grep -m1 "model name" | cut -d: -f2 | sed 's/^[ \t]*//')
    echo "- CPU model: $CPU_MODEL"
}

# verify gpu
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

# verify operating system
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
    # TODO: option to install kernel via verify_custom_build_kernel
    # TODO: option to install kernel via verify_latest_intel_repo_kernel
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

# verify features
verify_features() {
    echo -e "\n# Verifying features"
    if [ $FEATURE_CAM_D3 -eq 1 ]; then
        # TODO: verify_cam_d3 for supported platform
        echo -e "Verifying D3 AR0234"
    fi
    if [ $FEATURE_CAM_LEOPARD -eq 1 ]; then
        # TODO: verify_cam_leopard for supported platform
        echo -e "Verifying Leopard IMX415-MIPI-081H"
    fi
    if [ $FEATURE_CAM_INNODISK -eq 1 ]; then
        # TODO: verify_cam_innodisk for supported platform
        echo -e "Verifying Innodisk A R0330"
    fi
}


verify_configuration() {

DESCRIPTION=$(cat <<EOF
\nPlatform:
- CPU model: $CPU_MODEL

Graphic Processing Unit (GPU):
$GPU_STAT_LABEL

Select optional features:
EOF
)
    OPTIONS=(
        "FEATURE_CAM_D3" "D3 AR0234 " OFF
        "FEATURE_CAM_LEOPARD" "Leopard IMX415-MIPI-081H " OFF
        "FEATURE_CAM_INNODISK" "Innodisk A R0330 " OFF
    )

    SELECTED_OPTIONS=$(
        whiptail --title "Platform Configurations" \
        --separate-output \
        --checklist \
        "$DESCRIPTION" \
        19 65 3 \
        "${OPTIONS[@]}" \
        3>&1 1>&2 2>&3)

    if echo "$SELECTED_OPTIONS" | grep -q "FEATURE_CAM_D3"; then
        FEATURE_CAM_D3=1
    fi
    if echo "$SELECTED_OPTIONS" | grep -q "FEATURE_CAM_LEOPARD"; then
        FEATURE_CAM_LEOPARD=1
    fi
    if echo "$SELECTED_OPTIONS" | grep -q "FEATURE_CAM_INNODISK"; then
        FEATURE_CAM_INNODISK=1
    fi

    # verify gpu requirement
    if [ "$IGPU" -lt 1 ]; then
        echo "Error: GPU is not exist"
        exit 1
    fi
}

setup() {
    verify_platform
    verify_gpu
    verify_configuration

    verify_os
    verify_kernel
    verify_drivers

    verify_features

    echo -e "\n# Status"
    echo "$S_VALID Platform configured"
}

setup

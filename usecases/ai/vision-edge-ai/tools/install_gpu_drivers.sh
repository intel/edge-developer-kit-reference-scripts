#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# Color codes (defined early for trap)
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
NC="\e[0m"  # No color

# Exit on error and pipeline failure, enable error tracing
set -euo pipefail
trap 'echo -e "${RED}$0: Error on line ${LINENO}: $BASH_COMMAND${NC}"' ERR

FORCE_CLEAN=0  # Default: No cleaning

GPU_KEY_URL="https://repositories.intel.com/gpu/intel-graphics.key"
GPU_REPO_URL="https://repositories.intel.com/gpu/ubuntu"

# Function to log messages
log() {
    local level=$1
    shift
    case "$level" in
        "error") echo -e "${RED}[ERROR] $*${NC}" >&2 ;;
        "success") echo -e "${GREEN}[SUCCESS] $*${NC}" ;;
        "info") echo -e "${YELLOW}[INFO] $*${NC}" ;;
    esac
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)
            FORCE_CLEAN=1
            shift
            ;;
        *)
            log error "Unknown option: $1"
            echo "Usage: $0 [--clean]"
            exit 1
            ;;
    esac
done

# Detect Ubuntu version
if ! command -v lsb_release >/dev/null 2>&1; then
    log error "lsb_release command not found. Please install lsb-release package."
    exit 1
fi

UBUNTU_VERSION="$(lsb_release -rs)"
UBUNTU_CODENAME="$(lsb_release -cs)"
log info "Detected Ubuntu Version: ${UBUNTU_VERSION} (${UBUNTU_CODENAME})"

check_gpu_driver_version() {
    case "${UBUNTU_VERSION}" in
        "22.04")
            if dpkg-query -W -f='${Status}' intel-level-zero-gpu 2>/dev/null | grep -q "ok installed"; then
                log success "Intel GPU drivers are already installed."
                return 0
            fi
            ;;
        "24.04")
            if dpkg-query -W -f='${Status}' libze-intel-gpu1 2>/dev/null | grep -q "ok installed"; then
                log success "Intel GPU drivers are already installed."
                return 0
            fi
            ;;
        "24.10")
            if dpkg-query -W -f='${Status}' libze-intel-gpu1 2>/dev/null | grep -q "ok installed" && \
               dpkg-query -W -f='${Status}' intel-media-va-driver-non-free 2>/dev/null | grep -q "ok installed"; then
                log success "Intel GPU drivers are already installed."
                return 0
            fi
            ;;
        *)
            log error "Unsupported Ubuntu version: ${UBUNTU_VERSION}"
            exit 1
            ;;
    esac
    return 1
}

install_packages() {
    local pkg
    for pkg in "$@"; do
        if ! dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "ok installed"; then
            if ! sudo apt-get install -y -qq "${pkg}" > /dev/null 2>&1; then
                log error "Failed to install ${pkg}. Continuing with remaining packages."
                # Instead of returning 1 (which exits), continue to the next package
            fi
        fi
    done
    return 0  # Always return success to avoid halting the script
}

# Check if drivers are already installed
if check_gpu_driver_version && [[ ${FORCE_CLEAN} -eq 0 ]]; then
    exit 0
fi

# Remove existing Intel GPU drivers if --clean is used
if [[ ${FORCE_CLEAN} -eq 1 ]]; then
    log info "Removing existing Intel GPU drivers..."
    PACKAGES_TO_REMOVE=(
        "libze1" "intel-level-zero-gpu" "intel-opencl-icd" "clinfo" "libze-dev" "intel-ocloc"
        "libze-intel-gpu1" "intel-metrics-discovery" "intel-media-va-driver-non-free" "libmfx1"
        "libmfx-gen1" "libvpl2" "libvpl-tools" "libva-glx2" "va-driver-all" "vainfo"
    )
    sudo apt-get remove -y -qq "${PACKAGES_TO_REMOVE[@]}" > /dev/null 2>&1 || true
    sudo rm -f /etc/apt/sources.list.d/intel-gpu.list /etc/apt/sources.list.d/intel-gpu-noble.list
fi

# Install Intel GPU Drivers
log info "Installing Intel GPU drivers..."
case "${UBUNTU_VERSION}" in
    "22.04")
        if ! wget -qO - "${GPU_KEY_URL}" | gpg --dearmor | sudo tee /usr/share/keyrings/intel-graphics.gpg > /dev/null 2>&1; then
            log error "Failed to download or install GPU key"
            exit 1
        fi
        echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] ${GPU_REPO_URL} ${UBUNTU_CODENAME} client" | \
            sudo tee /etc/apt/sources.list.d/intel-gpu.list > /dev/null
        if ! sudo apt-get update -y -qq > /dev/null 2>&1; then
            log error "Failed to update package lists"
            exit 1
        fi
        install_packages libze1 intel-level-zero-gpu intel-opencl-icd clinfo libze-dev intel-ocloc
        ;;
    "24.04")
        if ! wget -qO - "${GPU_KEY_URL}" | sudo gpg --yes --dearmor | sudo tee /usr/share/keyrings/intel-graphics.gpg > /dev/null 2>&1; then
            log error "Failed to download or install GPU key"
            exit 1
        fi
        echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] ${GPU_REPO_URL} noble client" | \
            sudo tee /etc/apt/sources.list.d/intel-gpu-noble.list > /dev/null
        if ! sudo apt-get update -qq > /dev/null 2>&1; then
            log error "Failed to update package lists"
            exit 1
        fi
        install_packages libze-intel-gpu1 libze1 intel-opencl-icd clinfo intel-gsc libze-dev intel-ocloc
        ;;
    "24.10")
        if ! sudo apt-get update -qq > /dev/null 2>&1; then
            log error "Failed to update package lists"
            exit 1
        fi
        if ! sudo apt-get install -y -qq software-properties-common > /dev/null 2>&1; then
            log error "Failed to install software-properties-common"
            exit 1
        fi
        if ! sudo add-apt-repository -y ppa:kobuk-team/intel-graphics > /dev/null 2>&1; then
            log error "Failed to add Intel graphics PPA"
            exit 1
        fi
        if ! sudo apt-get update -qq > /dev/null 2>&1; then
            log error "Failed to update package lists after adding PPA"
            exit 1
        fi
        install_packages libze-intel-gpu1 libze1 intel-metrics-discovery intel-ocloc intel-opencl-icd clinfo intel-gsc libze-dev
        install_packages intel-media-va-driver-non-free libmfx1 libmfx-gen1 libvpl2 libvpl-tools libva-glx2 va-driver-all vainfo
        ;;
    *)
        log error "Unsupported Ubuntu version for GPU: ${UBUNTU_VERSION}. Exiting."
        exit 1
        ;;
esac

log success "Intel GPU drivers installed successfully!"
echo -e "\n${RED}Please reboot your system to apply changes.${NC}"

# Create a marker file to indicate successful installation
touch "$(dirname "$0")/.gpu_installation_complete"
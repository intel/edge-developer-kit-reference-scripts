#!/bin/bash

# Exit on error and pipeline failure, enable error tracing
set -euo pipefail
trap 'echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit 1' ERR

FORCE_CLEAN=0  # Default: No cleaning

GPU_KEY_URL="https://repositories.intel.com/gpu/intel-graphics.key"
GPU_REPO_URL="https://repositories.intel.com/gpu/ubuntu"

# Color codes
RED="\e[31m"
GREEN="\e[32m"
NC="\e[0m"  # No color

# Function to log messages with colors
log() {
    local level=$1
    shift
    case "$level" in
        "error") echo -e "${RED}Error: $*${NC}" >&2 ;;
        "success") echo -e "${GREEN}$*${NC}" ;;
        *) echo -e "$*" ;;
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

log "Detected Ubuntu Version: ${UBUNTU_VERSION} (${UBUNTU_CODENAME})"

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
        if dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "ok installed"; then
            log "${pkg} is already installed. Skipping."
        else
            if ! sudo apt-get install -y "${pkg}"; then
                log error "Failed to install ${pkg}"
                return 1
            fi
        fi
    done
    return 0
}

# Check if drivers are already installed
if check_gpu_driver_version && [[ ${FORCE_CLEAN} -eq 0 ]]; then
    log success "Required GPU drivers are already installed. No action needed."
    exit 0
fi

# Remove existing Intel GPU drivers if --clean is used
if [[ ${FORCE_CLEAN} -eq 1 ]]; then
    log "Removing existing Intel GPU drivers..."
    # Use an array for package names to avoid word splitting
    PACKAGES_TO_REMOVE=(
        "libze1"
        "intel-level-zero-gpu"
        "intel-opencl-icd"
        "clinfo"
        "libze-dev"
        "intel-ocloc"
        "libze-intel-gpu1"
        "intel-metrics-discovery"
        "intel-media-va-driver-non-free"
        "libmfx1"
        "libmfx-gen1"
        "libvpl2"
        "libvpl-tools"
        "libva-glx2"
        "va-driver-all"
        "vainfo"
    )
    
    sudo apt-get remove -y "${PACKAGES_TO_REMOVE[@]}" || true
    sudo rm -f /etc/apt/sources.list.d/intel-gpu.list /etc/apt/sources.list.d/intel-gpu-noble.list
fi

# Install Intel GPU Drivers
log "Installing Intel GPU drivers..."
case "${UBUNTU_VERSION}" in
    "22.04")
        if ! wget -qO - "${GPU_KEY_URL}" | gpg --dearmor | sudo tee /usr/share/keyrings/intel-graphics.gpg > /dev/null; then
            log error "Failed to download or install GPU key"
            exit 1
        fi
        
        echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] ${GPU_REPO_URL} ${UBUNTU_CODENAME} client" | \
            sudo tee /etc/apt/sources.list.d/intel-gpu.list > /dev/null
        
        if ! sudo apt-get update -y -qq; then
            log error "Failed to update package lists"
            exit 1
        fi
        
        install_packages libze1 intel-level-zero-gpu intel-opencl-icd clinfo libze-dev intel-ocloc
        ;;
        
    "24.04")
        if ! wget -qO - "${GPU_KEY_URL}" | sudo gpg --yes --dearmor | sudo tee /usr/share/keyrings/intel-graphics.gpg > /dev/null; then
            log error "Failed to download or install GPU key"
            exit 1
        fi
        
        echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] ${GPU_REPO_URL} noble client" | \
            sudo tee /etc/apt/sources.list.d/intel-gpu-noble.list > /dev/null
            
        if ! sudo apt-get update; then
            log error "Failed to update package lists"
            exit 1
        fi
        
        install_packages libze-intel-gpu1 libze1 intel-opencl-icd clinfo intel-gsc libze-dev intel-ocloc
        ;;
        
    "24.10")
        if ! sudo apt-get update -qq; then
            log error "Failed to update package lists"
            exit 1
        fi
        
        if ! sudo apt-get install -y software-properties-common; then
            log error "Failed to install software-properties-common"
            exit 1
        fi
        
        if ! sudo add-apt-repository -y ppa:kobuk-team/intel-graphics; then
            log error "Failed to add Intel graphics PPA"
            exit 1
        fi
        
        if ! sudo apt-get update; then
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
#!/bin/bash

# Exit on error and pipeline failure, enable error tracing
set -euo pipefail
trap 'echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit 1' ERR

# Default configuration
FORCE_CLEAN=0  # Default: No cleaning
NPU_VERSION="${NPU_VERSION:-"1.13.0"}"
NPU_RELEASE_URL="https://github.com/intel/linux-npu-driver/releases/download/v${NPU_VERSION}"

# Color codes
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
NC="\e[0m"  # No color

# Function to log messages with colors
log() {
    local level=$1
    shift
    case "$level" in
        "error") echo -e "${RED}Error: $*${NC}" >&2 ;;
        "success") echo -e "${GREEN}$*${NC}" ;;
        "info") echo -e "${BLUE}$*${NC}" ;;
        *) echo -e "$*" ;;
    esac
}

# Function to check dependencies
check_dependencies() {
    local cmds=("wget" "dpkg" "apt-get" "lsb_release")
    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log error "Required command '$cmd' not found. Please install it first."
            return 1
        fi
    done
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

# Check dependencies
check_dependencies || exit 1

# Detect Ubuntu version
UBUNTU_VERSION="$(lsb_release -rs)"

# If Ubuntu 24.10, use 24.04 NPU drivers
if [[ "${UBUNTU_VERSION}" == "24.10" ]]; then
    UBUNTU_VERSION="24.04"
fi

log info "Using Intel NPU driver version: ${NPU_VERSION} for Ubuntu ${UBUNTU_VERSION}"

# Remove deadsnakes repository if present
if grep -q "deadsnakes/ppa" /etc/apt/sources.list.d/* 2>/dev/null; then
    log info "Removing deadsnakes repository..."
    if ! sudo add-apt-repository --remove ppa:deadsnakes/ppa; then
        log error "Failed to remove deadsnakes repository"
        exit 1
    fi
    if ! sudo apt-get update -y; then
        log error "Failed to update package lists"
        exit 1
    fi
fi

# Remove existing Intel NPU drivers if --clean is used
if [[ ${FORCE_CLEAN} -eq 1 ]]; then
    log info "Removing existing Intel NPU drivers..."
    sudo dpkg --purge --force-remove-reinstreq intel-driver-compiler-npu intel-fw-npu intel-level-zero-npu || true
fi

# Check if NPU drivers are already installed with correct version
INSTALLED_NPU_VERSION=$(dpkg-query -W -f='${Version}' intel-driver-compiler-npu 2>/dev/null | cut -d'-' -f1 | cut -d '.' -f1-3 || true)
if [[ -z "${INSTALLED_NPU_VERSION}" ]]; then
    log info "Intel NPU driver is not installed. Proceeding with installation..."
elif [[ "${INSTALLED_NPU_VERSION}" == "${NPU_VERSION}" ]]; then
    log success "Intel NPU drivers v${NPU_VERSION} are already installed. Skipping installation."
    exit 0
else
    log info "Different version detected (installed: ${INSTALLED_NPU_VERSION}, expected: ${NPU_VERSION}). Updating..."
fi

log info "Downloading and installing Intel NPU drivers..."

# Define the base package names
PACKAGES=(
    "intel-driver-compiler-npu"
    "intel-fw-npu"
    "intel-level-zero-npu"
)

# Create temporary directory for downloads
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT

# Download and install NPU driver packages
for package in "${PACKAGES[@]}"; do
    DEB_FILE="${package}_${NPU_VERSION}.20250131-13074932693_ubuntu${UBUNTU_VERSION}_amd64.deb"
    log info "Downloading ${DEB_FILE}..."
    if ! wget -q "${NPU_RELEASE_URL}/${DEB_FILE}" -P "${TEMP_DIR}"; then
        log error "Failed to download ${DEB_FILE}"
        exit 1
    fi
done

# Install required dependencies
log info "Installing dependencies..."
if ! sudo apt-get update -y; then
    log error "Failed to update package lists"
    exit 1
fi

if ! sudo apt-get install -y libtbb12; then
    log error "Failed to install dependencies"
    exit 1
fi

# Install downloaded NPU packages
log info "Installing NPU driver packages..."
if ! sudo dpkg -i "${TEMP_DIR}"/*.deb; then
    log error "Failed to install .deb packages"
    exit 1
fi

# Configure permissions
log info "Configuring permissions..."
if ! sudo usermod -a -G render "${USER}"; then
    log error "Failed to add user to render group"
    exit 1
fi

# Persist permission changes
UDEV_RULE='SUBSYSTEM=="accel", KERNEL=="accel*", GROUP="render", MODE="0660"'
UDEV_FILE="/etc/udev/rules.d/10-intel-vpu.rules"

echo "${UDEV_RULE}" | sudo tee "${UDEV_FILE}" > /dev/null

if ! sudo udevadm control --reload-rules; then
    log error "Failed to reload udev rules"
    exit 1
fi

if ! sudo udevadm trigger --subsystem-match=accel; then
    log error "Failed to trigger udev rules"
    exit 1
fi

# Final message
log success "Intel NPU drivers (v${NPU_VERSION}) installed successfully!"
echo -e "\n${RED}Please reboot your system to apply changes.${NC}"

# Create a marker file to indicate successful installation
touch "$(dirname "$0")/.npu_installation_complete"
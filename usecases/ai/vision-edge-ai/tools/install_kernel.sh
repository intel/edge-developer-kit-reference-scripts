#!/bin/bash

# Exit on error and pipeline failure, enable error tracing
set -euo pipefail
trap 'echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit 1' ERR

# Default configuration
FORCE_CLEAN=0  # Default: No cleaning
KERNEL_VERSION="${KERNEL_VERSION:-v6.14.0-rc1}"
# Remove .0 from version string for git operations
GIT_VERSION="${KERNEL_VERSION/.0/}"
KERNEL_REPO="https://github.com/torvalds/linux.git"
KERNEL_DIR="$(pwd)/linux"  # Clone in the current directory

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

# Function to check required commands
check_dependencies() {
    local deps=("git" "make" "gcc" "bc" "flex" "bison")
    for cmd in "${deps[@]}"; do
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

# Check if the required kernel version is already installed
CURRENT_KERNEL="$(uname -r)"
if [[ "${CURRENT_KERNEL}" == *"${KERNEL_VERSION#v}"* ]] && [[ ${FORCE_CLEAN} -eq 0 ]]; then
    log success "Kernel ${KERNEL_VERSION} is already installed and running. Skipping build and installation."
    exit 0
fi

# Check dependencies before proceeding
check_dependencies || exit 1

# Check if Kernel source already exists
if [[ -d "${KERNEL_DIR}" ]]; then
    if [[ ${FORCE_CLEAN} -eq 1 ]]; then
        log "Cleaning existing kernel source..."
        rm -rf "${KERNEL_DIR}"
    else
        log "Kernel source already exists at ${KERNEL_DIR}. Skipping cloning."
    fi
fi

# Clone Kernel source if needed
if [[ ! -d "${KERNEL_DIR}" ]]; then
    log "Updating package list and installing dependencies..."
    if ! sudo apt-get update -y -qq; then
        log error "Failed to update package list"
        exit 1
    fi
    
    if ! sudo apt-get install -y build-essential flex bison libssl-dev libelf-dev bc git fakeroot ccache; then
        log error "Failed to install dependencies"
        exit 1
    fi
    
    log "Cloning kernel source from ${KERNEL_REPO} using version ${GIT_VERSION}..."
    if ! git clone --depth=1 --branch "${GIT_VERSION}" "${KERNEL_REPO}" "${KERNEL_DIR}"; then
        log error "Failed to clone kernel repository"
        exit 1
    fi
fi

# Build the Kernel
cd "${KERNEL_DIR}" || exit 1

log "Checking out kernel version ${GIT_VERSION}..."
if ! git checkout "${GIT_VERSION}"; then
    log error "Failed to checkout kernel version"
    exit 1
fi

log "Using existing kernel configuration..."
# Fix for SC2046: Quote to prevent word splitting
if ! cp "/boot/config-$(uname -r)" .config; then
    log error "Failed to copy kernel config"
    exit 1
fi

if ! make olddefconfig; then
    log error "Failed to update kernel config"
    exit 1
fi

# Disable module signatures and certificates
log "Disabling module signatures and certificates..."
scripts/config --disable CONFIG_MODULE_SIG
scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
scripts/config --set-str CONFIG_SYSTEM_REVOCATION_KEYS ""

# Compile the Kernel
log "Compiling the kernel (this may take a while)..."
# Fix for SC2046: Quote to prevent word splitting
if ! make -j"$(nproc)"; then
    log error "Kernel compilation failed"
    exit 1
fi

# Get the expected kernel release name
NEW_KERNEL="$(make kernelrelease)"

# Check if the kernel image is already installed
if [[ -f "/boot/vmlinuz-${NEW_KERNEL}" ]] && [[ ${FORCE_CLEAN} -eq 0 ]]; then
    log success "Kernel ${NEW_KERNEL} is already installed. Skipping installation."
    exit 0
fi

# Install Kernel
log "Installing kernel modules..."
if ! sudo make modules_install; then
    log error "Failed to install kernel modules"
    exit 1
fi

log "Installing new kernel..."
if ! sudo make install; then
    log error "Failed to install kernel"
    exit 1
fi

# Update bootloader and initramfs
log "Generating initramfs for ${NEW_KERNEL}..."
if ! sudo update-initramfs -c -k "${NEW_KERNEL}"; then
    log error "Failed to generate initramfs"
    exit 1
fi

log "Updating GRUB..."
if ! sudo update-grub; then
    log error "Failed to update GRUB"
    exit 1
fi

# Completion message
log success "Kernel installation complete."
echo -e "\n${RED}Please reboot your system to apply changes.${NC}"

# Create a marker file to indicate successful installation
touch "${KERNEL_DIR}/.installation_complete"
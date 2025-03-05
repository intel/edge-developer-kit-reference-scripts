#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# Exit on error and pipeline failure, enable error tracing
set -euo pipefail
trap 'echo -e "${RED}$0: Error on line ${LINENO}: $BASH_COMMAND${NC}"' ERR

# Default configuration
FORCE_CLEAN=0
KERNEL_VERSION="${KERNEL_VERSION:-v6.14.0-rc1}"
GIT_VERSION="${KERNEL_VERSION/.0/}"
KERNEL_REPO="https://github.com/torvalds/linux.git"
KERNEL_DIR="$(pwd)/linux"

# Color codes
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
NC="\e[0m"  # No color

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

# Get current running kernel version
CURRENT_KERNEL="$(uname -r)"
TARGET_KERNEL_VERSION="${KERNEL_VERSION#v}" # Remove 'v' prefix from KERNEL_VERSION for comparison

log info "Current running kernel: ${CURRENT_KERNEL}"
log info "Target kernel version: ${TARGET_KERNEL_VERSION}"

# Check if the target kernel is already running
if [[ "${CURRENT_KERNEL}" == *"${TARGET_KERNEL_VERSION}"* ]]; then
    log success "Kernel ${TARGET_KERNEL_VERSION} is already installed and running. No installation needed."
    exit 0
fi

log info "Kernel versions differ. Proceeding with installation..."

# Fix broken package installations (Suppress errors)
fix_broken_packages() {
    sudo dpkg --configure -a >/dev/null 2>&1
}

# Remove old DKMS modules (Suppress errors)
clean_dkms() {
    DKMS_MODULES=$(dkms status | awk '{print $1}')
    for module in $DKMS_MODULES; do
        sudo dkms remove "$module" --all >/dev/null 2>&1
    done
    sudo rm -rf /var/lib/dkms/* /var/crash/* >/dev/null 2>&1
}

# Remove and reinstall kernel headers (Suppress errors)
fix_kernel_headers() {
    KERNEL_HEADERS="linux-headers-$(uname -r)"
    sudo apt-get remove --purge -y "$KERNEL_HEADERS" >/dev/null 2>&1 || true
    sudo apt-get update -y >/dev/null 2>&1
    sudo apt-get install -y --reinstall linux-headers-generic linux-image-generic dkms >/dev/null 2>&1
}

# Run fixes silently before proceeding
fix_broken_packages
clean_dkms
fix_kernel_headers

# Check if Kernel source exists
if [[ -d "${KERNEL_DIR}" && ${FORCE_CLEAN} -eq 1 ]]; then
    log info "Cleaning existing kernel source..."
    rm -rf "${KERNEL_DIR}"
fi

# Clone Kernel source if needed
if [[ ! -d "${KERNEL_DIR}" ]]; then
    log info "Cloning kernel source..."
    git clone --depth=1 --branch "${GIT_VERSION}" "${KERNEL_REPO}" "${KERNEL_DIR}" >/dev/null 2>&1
fi

# Build the Kernel
cd "${KERNEL_DIR}" || exit 1

git checkout "${GIT_VERSION}" >/dev/null 2>&1
cp "/boot/config-$(uname -r)" .config || log error "Failed to copy kernel config"
make olddefconfig >/dev/null 2>&1 || log error "Failed to update kernel config"

# Disable module signatures and certificates
scripts/config --disable CONFIG_MODULE_SIG
scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
scripts/config --set-str CONFIG_SYSTEM_REVOCATION_KEYS ""

# Compile the Kernel
log info "Compiling the kernel (this may take a while)..."
make -j"$(nproc)" >/dev/null 2>&1 || log error "Kernel compilation failed"

NEW_KERNEL="$(make kernelrelease)"
log success "Kernel compiled successfully: ${NEW_KERNEL}"

# Install Kernel
log info "Installing kernel..."
sudo make modules_install >/dev/null 2>&1 || log error "Failed to install kernel modules"
sudo make install >/dev/null 2>&1 || log error "Failed to install kernel"

# Generate initramfs for the new kernel
log info "Generating initramfs for ${TARGET_KERNEL_VERSION}..."
sudo update-initramfs -c -k "${TARGET_KERNEL_VERSION}" >/dev/null 2>&1 || log error "Failed to generate initramfs"

# Update bootloader and initramfs
log info "Updating grub..."
sudo update-grub >/dev/null 2>&1

log success "Kernel installation complete. Please reboot your system."
touch "${KERNEL_DIR}/.installation_complete"

#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# Exit on error and pipeline failure, enable error tracing
set -euo pipefail
trap 'echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit 1' ERR

# Default configuration
FORCE_CLEAN=0  # Default: No cleaning

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

# Function to check and install dependencies
check_dependencies() {
    local cmds=("curl" "dpkg" "apt-get" "lsb_release" "gpg")
    local install_list=()

    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            install_list+=("$cmd")
        fi
    done

    if [[ "${#install_list[@]}" -ne 0 ]]; then
        log info "Installing missing dependencies..."
        sudo apt-get update -y -qq > /dev/null 2>&1
        sudo apt-get install -y -qq "${install_list[@]}" > /dev/null 2>&1 || { log error "Failed to install dependencies"; exit 1; }
    fi
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

UBUNTU_VERSION="$(lsb_release -rs)"
UBUNTU_CODENAME="$(lsb_release -cs)"

# If running Ubuntu 24.10, force using 24.04 (Noble) repository
if [[ "${UBUNTU_VERSION}" == "24.10" ]]; then
    log info "Ubuntu 24.10 detected, using repository for Ubuntu 24.04 (Noble)"
    UBUNTU_VERSION="24.04"
    UBUNTU_CODENAME="noble"
fi

log info "Detected Ubuntu Version: ${UBUNTU_VERSION} (${UBUNTU_CODENAME})"

# Check if Docker is already installed
if command -v docker &>/dev/null && [[ ${FORCE_CLEAN} -eq 0 ]]; then
    log success "Docker is already installed. Skipping installation."
    exit 0
fi

# Uninstall old versions if --clean is used
if [[ ${FORCE_CLEAN} -eq 1 ]]; then
    log info "Removing existing Docker installation..."
    sudo apt-get purge -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1 || true
    sudo rm -rf /var/lib/docker /var/lib/containerd
    sudo rm -f /etc/apt/sources.list.d/docker.list
    sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
fi

# Add Docker's official GPG key and repository
log info "Configuring Docker repository..."
DOCKER_GPG_KEY="/usr/share/keyrings/docker-archive-keyring.gpg"
sudo rm -f "${DOCKER_GPG_KEY}"
if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o "${DOCKER_GPG_KEY}" > /dev/null 2>&1; then
    log error "Failed to add Docker GPG key"
    exit 1
fi
sudo chmod a+r "${DOCKER_GPG_KEY}"
DOCKER_REPO_FILE="/etc/apt/sources.list.d/docker.list"
echo "deb [arch=$(dpkg --print-architecture) signed-by=${DOCKER_GPG_KEY}] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" | sudo tee "${DOCKER_REPO_FILE}" > /dev/null

# Update package list and install Docker
log info "Installing Docker..."
sudo apt-get update -y -qq > /dev/null 2>&1 || { log error "Failed to update package list"; exit 1; }
sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1 || { log error "Failed to install Docker packages"; exit 1; }

# Restart Docker service
sudo systemctl restart docker > /dev/null 2>&1 || { log error "Failed to restart Docker service"; exit 1; }

# Add user to Docker group if not already added
if ! groups | grep -q "\bdocker\b"; then
    log info "Adding user to docker group..."
    sudo usermod -aG docker "${USER}" > /dev/null 2>&1 || { log error "Failed to add user to docker group"; exit 1; }
    log info "User added to docker group. Please log out and back in to apply changes."
fi

# Completion message
log success "Docker installation complete."

# Create a marker file to indicate successful installation
touch "$(dirname "$0")/.docker_installation_complete"
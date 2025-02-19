#!/bin/bash

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

# Function to check dependencies
check_dependencies() {
    local cmds=("curl" "dpkg" "apt-get" "lsb_release")
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
UBUNTU_CODENAME="$(lsb_release -cs)"

echo -e "Detected Ubuntu Version: ${RED}${UBUNTU_VERSION}${NC} (${UBUNTU_CODENAME})"

# Check if Docker is already installed
if command -v docker &> /dev/null && [[ ${FORCE_CLEAN} -eq 0 ]]; then
    log success "Docker is already installed. Skipping installation."
    exit 0
fi

# Uninstall old versions if --clean is used
if [[ ${FORCE_CLEAN} -eq 1 ]]; then
    log info "Removing existing Docker installation..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    sudo rm -rf /var/lib/docker /var/lib/containerd
fi

# Update package list
log info "Updating package list..."
if ! sudo apt-get update -y -qq; then
    log error "Failed to update package list"
    exit 1
fi

# Install required packages only if they are missing
REQUIRED_PACKAGES=(
    "ca-certificates"
    "curl"
    "gnupg"
    "lsb-release"
)

for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  ${pkg} "; then
        log info "Installing ${pkg}..."
        if ! sudo apt-get install -y "${pkg}"; then
            log error "Failed to install ${pkg}"
            exit 1
        fi
    fi
done

# Add Docker's official GPG key if not already present
DOCKER_GPG_KEY="/etc/apt/keyrings/docker.gpg"
if [ ! -f "${DOCKER_GPG_KEY}" ]; then
    sudo mkdir -p /etc/apt/keyrings
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee "${DOCKER_GPG_KEY}" > /dev/null; then
        log error "Failed to download Docker GPG key"
        exit 1
    fi
fi

# Set up the Docker repository
DOCKER_REPO_FILE="/etc/apt/sources.list.d/docker.list"
if [ ! -f "${DOCKER_REPO_FILE}" ]; then
    log info "Adding Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=${DOCKER_GPG_KEY}] https://download.docker.com/linux/ubuntu \
      ${UBUNTU_CODENAME} stable" | sudo tee "${DOCKER_REPO_FILE}" > /dev/null
fi

# Update package list again
log info "Updating package list with Docker repository..."
if ! sudo apt-get update -y -qq; then
    log error "Failed to update package list"
    exit 1
fi

# Install Docker Engine
log info "Installing Docker packages..."
if ! sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
    log error "Failed to install Docker packages"
    exit 1
fi

# Restart Docker service
log info "Restarting Docker service..."
if ! sudo systemctl restart docker; then
    log error "Failed to restart Docker service"
    exit 1
fi

# Verify installation
log info "Verifying Docker installation..."
if ! sudo docker --version; then
    log error "Docker installation verification failed"
    exit 1
fi

# Add user to Docker group if not already added
if ! groups | grep -q "\bdocker\b"; then
    log info "Adding user to docker group..."
    if ! sudo gpasswd -a "${USER}" docker; then
        log error "Failed to add user to docker group"
        exit 1
    fi
    newgrp docker
fi

# Completion message
log success "Docker installation complete."

# Create a marker file to indicate successful installation
touch "$(dirname "$0")/.docker_installation_complete"
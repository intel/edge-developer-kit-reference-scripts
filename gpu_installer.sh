#!/bin/bash

# Complete Intel Arc GPU Installation Script (BMG/DG2)
# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# This is a complete standalone script for Intel Arc BMG and DG2 GPU setup
# Supports Ubuntu 24.04 only with Intel Kobuk team PPA

set -e

# Symbols
S_ERROR="❌"
S_VALID="✅"

# Common GPU packages for both BMG and DG2
COMMON_GPU_PACKAGES=(
    "intel-level-zero-gpu"
    "libze1" 
    "intel-metrics-discovery"
    "intel-opencl-icd"
    "clinfo"
    "intel-gsc"
)

# Media and video acceleration packages
MEDIA_GPU_PACKAGES=(
    "intel-media-va-driver-non-free"
    "libmfx-gen1"
    "libvpl2"
    "libvpl-tools"
    "libva-glx2"
    "va-driver-all"
    "vainfo"
)

# Optional packages for advanced features
OPTIONAL_GPU_PACKAGES=(
    "libze-dev"
    "intel-ocloc"
    "libze-intel-gpu-raytracing"
)

# Dependencies
DEPENDENCIES=(
    "curl"
    "wget"
    "gpg-agent"
    "software-properties-common"
)

ARC_PCI=(
    # Battlemage (BMG)
    "8086:e20b"  # Intel Arc BMG (Battlemage) B580
    "8086:e20c"  # Intel Arc BMG (Battlemage) B760
    "8086:5690"  # Intel Arc BMG (Battlemage) B760M
    "8086:e211"  # Intel Arc BMG (Battlemage) B60
    # Alchemist (DG2, Xe-HPG)
    "8086:5690"  # Intel Arc A770M Graphics
    "8086:5691"  # Intel Arc A730M Graphics
    "8086:5696"  # Intel Arc A570M Graphics
    "8086:5692"  # Intel Arc A550M Graphics
    "8086:5697"  # Intel Arc A530M Graphics
    "8086:5693"  # Intel Arc A370M Graphics
    "8086:5694"  # Intel Arc A350M Graphics
    "8086:56a0"  # Intel Arc A770 Graphics
    "8086:56a1"  # Intel Arc A750 Graphics
    "8086:56a2"  # Intel Arc A580 Graphics
    "8086:56a5"  # Intel Arc A380 Graphics
    "8086:56a6"  # Intel Arc A310 Graphics
    "8086:56b3"  # Intel Arc Pro A60 Graphics
    "8086:56b2"  # Intel Arc Pro A60M Graphics
    "8086:56b1"  # Intel Arc Pro A40/A50 Graphics
    "8086:56b0"  # Intel Arc Pro A30M Graphics
    "8086:56ba"  # Intel Arc A380E Graphics
    "8086:56bc"  # Intel Arc A370E Graphics
    "8086:56bd"  # Intel Arc A350E Graphics
    "8086:56bb"  # Intel Arc A310E Graphics
)
# Error handling function with proper output flushing
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    
    echo "$S_ERROR $message" >&2
    echo "" >&2
    
    # Flush output buffers
    sync
    sleep 0.1
    
    exit "$exit_code"
}

# Usage function
usage() {
    echo "Complete Intel Arc GPU Driver Installation Script"
    echo "Supports: Intel Arc BMG (Battlemage) and DG2 (Alchemist)"
    echo "Repository: Uses Intel Kobuk team PPA for all GPU drivers"
    echo "Supported OS: Ubuntu 24.04 only and HWE kernel"
}

# Check if running with appropriate privileges
check_privileges() {
    if [ ! "$EUID" -eq 0 ]; then
        error_exit "This script must be run with sudo or as root user"
    fi
}

# Configure kobuk repository for Intel Arc GPUs
configure_kobuk_repository() {
    echo -e "\n# Configuring Intel Kobuk GPU repository"
    
    # Check if repository is already configured
    local repo_file="/etc/apt/sources.list.d/kobuk-team-ubuntu-intel-graphics-noble.sources"
    if [ -e "$repo_file" ] || \
       ls /var/lib/apt/lists/ppa.launchpadcontent.net_kobuk-team_intel-graphics_ubuntu_dists_* >/dev/null 2>&1; then
        echo "$S_VALID Kobuk repository already configured"
        check_kobuk_version_info
        return 0
    fi
    
    echo "Adding Intel Kobuk GPU repository..."
    
    # Install prerequisites
    apt-get update
    apt-get install -y software-properties-common
    
    # Add kobuk team PPA repository
    if add-apt-repository -y ppa:kobuk-team/intel-graphics; then
        echo "$S_VALID Kobuk repository added successfully"
        
        # Update package lists
        apt update
        
        # Check repository commit/version information
        check_kobuk_version_info
    else
        error_exit "Failed to add Kobuk repository"
    fi
}

# Check and report kobuk repository version and commit information
check_kobuk_version_info() {
    echo -e "\n# Kobuk Repository Version Information"
    
    # Get repository information from apt sources
    local release_file
    release_file=$(find /var/lib/apt/lists/ -name "*kobuk-team*intel-graphics*Release" | head -1)
    
    if [ -n "$release_file" ] && [ -f "$release_file" ]; then
        echo "Repository Release Information:"
        local date version origin
        date=$(grep "Date:" "$release_file" 2>/dev/null | cut -d' ' -f2-)
        version=$(grep "Version:" "$release_file" 2>/dev/null | cut -d' ' -f2-)
        origin=$(grep "Origin:" "$release_file" 2>/dev/null | cut -d' ' -f2-)
        
        echo "  Date: ${date:-N/A}"
        echo "  Version: ${version:-N/A}"
        echo "  Origin: ${origin:-N/A}"
    else
        echo "Repository release file not found"
    fi
    
    # Check repository source information
    if command -v apt-cache >/dev/null 2>&1; then
        echo -e "\nPackage Version Information:"
        
        # Check key Intel packages from kobuk repository
        local packages=("intel-opencl-icd" "intel-level-zero-gpu" "intel-media-va-driver-non-free")
        for pkg in "${packages[@]}"; do
            local candidate_version
            candidate_version=$(apt-cache policy "$pkg" 2>/dev/null | grep "Candidate:" | awk '{print $2}')
            if [ -n "$candidate_version" ] && [ "$candidate_version" != "(none)" ]; then
                echo "  $pkg: $candidate_version"
                
                # Check if this package comes from kobuk repository
                local pkg_source
                pkg_source=$(apt-cache policy "$pkg" 2>/dev/null | grep -A5 "Candidate:" | grep -E "release.*kobuk|ppa.*kobuk" | head -1)
                if [ -n "$pkg_source" ]; then
                    echo "    Source: Kobuk team PPA"
                fi
            fi
        done
    fi
    
    # Check for installed Intel GPU packages and their versions
    if command -v dpkg >/dev/null 2>&1; then
        echo -e "\nInstalled Intel GPU Packages:"
        local installed_packages
        installed_packages=$(dpkg -l | grep -E "intel-(opencl|level-zero|gsc|media)" | awk '{print $2 " " $3}' 2>/dev/null)
        
        if [ -n "$installed_packages" ]; then
            echo "$installed_packages" | while IFS=' ' read -r pkg version; do
                echo "  $pkg: $version"
            done
        else
            echo "  No Intel GPU packages currently installed"
        fi
    fi
    
    # Try to extract commit information from package versions (if available)
    echo -e "\nRepository Commit Information:"
    local commit_info
    commit_info=$(apt-cache policy intel-opencl-icd 2>/dev/null | grep -o "ppa.*kobuk.*" | head -1)
    if [ -n "$commit_info" ]; then
        echo "  Repository: $commit_info"
    fi
    
    # Check for PPA information
    if [ -f "/etc/apt/sources.list.d/kobuk-team-ubuntu-intel-graphics-noble.sources" ]; then
        echo "  PPA Configuration: kobuk-team/intel-graphics"
        echo "  Ubuntu Version: noble (24.04)"
    else
        echo "  PPA Configuration: kobuk-team/intel-graphics"
        echo "  Expected Ubuntu Version: noble (24.04)"
    fi
    
    echo "$S_VALID Kobuk repository version information collected"
}

# Install packages function
install_packages() {
    local packages=("$@")
    local failed=0

    echo "Checking package requirements..."

    for package in "${packages[@]}"; do
        if [ -z "$package" ]; then
            continue
        fi
        if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
            echo "✓ Package '$package' is already installed"
            continue
        fi
        echo "➤ Installing $package..."
        apt-get update
        if ! apt-get install -y "$package"; then
            echo "❌ Failed to install $package"
            failed=1
        else
            echo "✓ Successfully installed $package"
        fi
    done

    if [ $failed -eq 1 ]; then
        return 2
    fi
    return 0
}

# Verify platform
verify_platform() {
    echo -e "\n# Verifying platform"
    local cpu_model
    cpu_model=$(< /proc/cpuinfo grep -m1 "model name" | cut -d: -f2 | sed 's/^[ \t]*//')
    echo "- CPU model: $cpu_model"
}

# Detect and verify Intel Arc GPU (mandatory check)
detect_intel_arc_gpu() {
    echo -e "\n# Detecting Intel Arc GPU"

    # Check if lspci is available
    if ! command -v lspci >/dev/null 2>&1; then
        error_exit "lspci command not found. Please install pciutils package: apt-get install pciutils"
    fi

    # Find all VGA/DISPLAY devices with Intel vendor
    local detected_pci_ids=()
    local found_supported=0
    local lspci_output
    lspci_output=$(lspci -nn | grep -Ei 'VGA|DISPLAY')

    while IFS= read -r line; do
        if [[ "$line" == *Intel* ]]; then
            # Extract PCI ID (format: [8086:xxxx])
            pci_id=$(echo "$line" | grep -oP '\[8086:[0-9a-fA-F]{4}\]' | tr -d '[]')
            if [ -n "$pci_id" ]; then
                detected_pci_ids+=("$pci_id")
                # Compare with supported ARC_PCI list
                for supported_id in "${ARC_PCI[@]}"; do
                    if [[ "$pci_id" == "$supported_id" ]]; then
                        found_supported=1
                        break 2
                    fi
                done
            fi
        fi
    done <<< "$lspci_output"

    if (( found_supported )); then
        echo -e "Detected supported Intel Arc GPU device(s):"
        for id in "${detected_pci_ids[@]}"; do
            echo "  - $id"
        done
        echo "$S_VALID Intel Arc GPU detected."
        return 0
    else
        echo "$S_ERROR No Intel Arc GPU found"
        echo "This script is specifically for Intel Arc BMG (Battlemage), DG2 (Alchemist)"
        echo ""
        echo "If you have an Intel Arc GPU that was not detected, please ensure:"
        echo "  - The GPU is properly seated and powered"
        echo "  - The system recognizes the hardware"
        echo "  - You're running a supported Intel Arc GPU model"
        echo ""
        error_exit "No compatible Intel Arc GPU found in the system"
    fi
}

# Verify OS compatibility
verify_os() {
    echo -e "\n# Verifying operating system"
    
    if [ ! -e /etc/os-release ]; then
        error_exit "/etc/os-release file not found"
    fi
    
    local current_os_id current_os_version current_os_codename
    current_os_id=$(grep -E '^ID=' /etc/os-release | cut -d'=' -f2- | tr -d '"')
    current_os_version=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d'=' -f2- | tr -d '"')
    current_os_codename=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d'=' -f2- | tr -d '"')
    
    # Only Ubuntu 24.04 is supported
    if [ "$current_os_id" != "ubuntu" ]; then
        error_exit "Only Ubuntu 24.04 is supported for Intel Arc GPU"
    fi
    
    # Check for supported Ubuntu version (24.04 only)
    case "$current_os_version" in
        "24.04")
            echo "$S_VALID OS version: $current_os_id $current_os_version ($current_os_codename)"
            ;;
        *)
            echo "$S_ERROR Unsupported Ubuntu version: $current_os_version"
            echo "Intel Arc GPU setup requires Ubuntu 24.04"
            echo "Current version: $current_os_id $current_os_version ($current_os_codename)"
            error_exit "Unsupported Ubuntu version: $current_os_version"
            ;;
    esac
}

# Verify and handle kernel requirements
verify_kernel() {
   echo -e "\n# Verifying kernel version"
   current_kernel=$(uname -r)
   echo "Current running kernel: $current_kernel"

   # Determine Ubuntu version
   ubuntu_version=$(lsb_release -rs)

   # Check if HWE meta-package is installed
   if dpkg -l | grep -q "linux-generic-hwe-${ubuntu_version}"; then
       echo "HWE kernel is already installed on Ubuntu $ubuntu_version."
   else
       apt update
       apt install -y "linux-generic-hwe-${ubuntu_version}"
    fi
}

# Configure user groups
configure_user_groups() {
    echo -e "\n# Configuring user groups"

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
}

# Remove all previously installed Intel GPU packages (if any)
remove_all_gpu_packages() {
    echo -e "\n# Removing all previously installed Intel GPU packages (if any)..."
    local all_packages=("${COMMON_GPU_PACKAGES[@]}" "${MEDIA_GPU_PACKAGES[@]}" "${OPTIONAL_GPU_PACKAGES[@]}")
    local to_remove=()
    for pkg in "${all_packages[@]}"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            to_remove+=("$pkg")
        fi
    done
    if [ ${#to_remove[@]} -gt 0 ]; then
        echo "Removing packages: ${to_remove[*]}"
        apt-get remove --purge -y "${to_remove[@]}"
        apt-get autoremove --purge -y
    else
        echo "No Intel GPU packages to remove."
    fi
}

# Install Intel Arc GPU drivers
install_gpu_drivers() {
    echo -e "\n# Installing Intel Arc GPU drivers"

    # Remove all previously installed GPU packages first
    remove_all_gpu_packages

    # Configure kobuk repository
    configure_kobuk_repository
    
    # Install dependencies
    echo "Installing dependencies..."
    install_packages "${DEPENDENCIES[@]}"
    local deps_result=$?
    if [ $deps_result -eq 0 ]; then
        echo "  Some dependencies were installed."
    elif [ $deps_result -eq 1 ]; then
        echo "  All dependencies were already installed."
    else
        echo "  An error occurred during dependency installation."
        error_exit "Failed to install dependencies"
    fi
    
    # Install common GPU packages
    echo "Installing common GPU driver packages..."
    install_packages "${COMMON_GPU_PACKAGES[@]}"
    local common_result=$?
    if [ $common_result -eq 1 ]; then
        echo "  Some common GPU packages were installed."
    elif [ $common_result -eq 0 ]; then
        echo "  All common GPU packages were already installed."
    else
        echo "  An error occurred during common GPU package installation."
        error_exit "Failed to install common GPU packages"
    fi
    
    # Install media packages
    echo "Installing media and video acceleration packages..."
    install_packages "${MEDIA_GPU_PACKAGES[@]}"
    local media_result=$?
    if [ $media_result -eq 0 ]; then
        echo "  Some media packages were installed."
    elif [ $media_result -eq 1 ]; then
        echo "  All media packages were already installed."
    else
        echo "  An error occurred during media package installation."
        error_exit "Failed to install media packages"
    fi
    
    # Install optional packages
    echo "Installing optional packages (PyTorch, ray tracing support)..."
    install_packages "${OPTIONAL_GPU_PACKAGES[@]}"
    local optional_result=$?
    if [ $optional_result -eq 0 ]; then
            echo "  Some optional packages were installed."
        elif [ $optional_result -eq 1 ]; then
            echo "  All optional packages were already installed."
        else
            echo "  An error occurred during optional package installation."
            error_exit "Failed to install optional packages"
        fi
    
    # Configure user groups
    configure_user_groups
    
    echo -e "\n $S_VALID Intel Arc GPU driver installation completed"
}

# Verify driver installation
verify_drivers() {
    echo -e "\n# Verifying driver installation"
    
    local verification_cmd="clinfo | grep 'Device Name\|Driver Version'"
    
    echo "Running verification: $verification_cmd"
    if eval "$verification_cmd" >/dev/null 2>&1; then
        local driver_info
        driver_info=$(eval "$verification_cmd" 2>/dev/null | head -n4)
        echo -e "$S_VALID Intel GPU Drivers installed and working:\n$driver_info"
    else
        echo "$S_ERROR Failed to verify GPU driver installation"
        echo "This may indicate a driver installation issue"
        echo "Please check system logs and try rebooting the system"
        exit 1
    fi
}

# Main setup function
main() {
   check_privileges
   
   echo "Complete Intel Arc GPU Driver Installation Script"
   echo "Supports: Intel Arc BMG (Battlemage) and DG2 (Alchemist)"
   echo "========================================================="
   
   verify_platform
   detect_intel_arc_gpu
   verify_os
   verify_kernel
   install_gpu_drivers
   verify_drivers
   
   echo -e "\n# Installation Summary"
   echo "$S_VALID Platform configured for Intel Arc GPU (BMG/DG2)"
   echo "System reboot or logout/login is recommended to ensure all changes take effect"
   echo ""
   echo "To verify installation after reboot:"
   echo "  clinfo"
   echo "  vainfo"
}

# Execute main function with all arguments
main

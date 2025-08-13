#!/bin/bash

# Complete Intel Arc GPU Installation Script (BMG/DG2)
# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# This is a complete standalone script for Intel Arc BMG and DG2 GPU setup
# Supports Ubuntu 24.04 only with Intel Kobuk team PPA

set -e

# Status indicators - using ASCII for better compatibility
readonly S_ERROR="[ERROR]"
readonly S_VALID="[✓]"
readonly S_INFO="[INFO]"

# Global variables
HAS_DGPU=0

# Package arrays - exported for external use
export COMPUTE_PACKAGES=(
   "libze-intel-gpu1"
   "libze1"
   "intel-metrics-discovery"
   "intel-opencl-icd"
   "clinfo"
   "intel-gsc"
)

export MEDIA_PACKAGES=(
   "intel-media-va-driver-non-free"
   "libmfx-gen1"
   "libvpl2"
   "libvpl-tools"
   "libva-glx2"
   "va-driver-all"
   "vainfo"
)

# Dependencies
readonly DEPENDENCIES=(
   "curl"
   "wget"
   "gpg-agent"
   "software-properties-common"
   "pciutils"
)

# Combined GPU packages for cleaner installation
readonly COMMON_GPU_PACKAGES=(
   "intel-level-zero-gpu"
   "${COMPUTE_PACKAGES[@]}"
)

readonly MEDIA_GPU_PACKAGES=(
   "${MEDIA_PACKAGES[@]}"
)

readonly OPTIONAL_GPU_PACKAGES=(
   "intel-ocloc"
   "level-zero-dev"
)

# GPU detection - simplified approach
# Install drivers for any Intel GPU found via lspci

# Utility functions
error_exit() {
   local message="$1"
   local exit_code="${2:-1}"
   
   echo "$S_ERROR $message" >&2
   echo "" >&2
   sync
   sleep 0.1
   exit "$exit_code"
}

log_info() {
   echo "$S_INFO $1"
}

log_success() {
   echo "$S_VALID $1"
}

# System verification functions
check_privileges() {
   if [ "$EUID" -ne 0 ]; then
      error_exit "This script must be run with sudo or as root user"
   fi
}

verify_platform() {
   echo -e "\n# Verifying platform"
   local cpu_model
   cpu_model=$(< /proc/cpuinfo grep -m1 "model name" | cut -d: -f2 | sed 's/^[ \t]*//')
   log_info "CPU model: $cpu_model"
}

verify_os() {
   echo -e "\n# Verifying operating system"
   
   if [ ! -e /etc/os-release ]; then
      error_exit "/etc/os-release file not found"
   fi
   
   local current_os_id current_os_version current_os_codename
   current_os_id=$(grep -E '^ID=' /etc/os-release | cut -d'=' -f2- | tr -d '"')
   current_os_version=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d'=' -f2- | tr -d '"')
   current_os_codename=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d'=' -f2- | tr -d '"')
   
   if [ "$current_os_id" != "ubuntu" ] || [ "$current_os_version" != "24.04" ]; then
      error_exit "Only Ubuntu 24.04 is supported. Current: $current_os_id $current_os_version"
   fi
   
   log_success "OS version: $current_os_id $current_os_version ($current_os_codename)"
}

verify_kernel() {
   echo -e "\n# Verifying kernel version"
   local current_kernel ubuntu_version
   current_kernel=$(uname -r)
   ubuntu_version=$(lsb_release -rs)
   
   log_info "Current running kernel: $current_kernel"
   
   if ! dpkg -l | grep -q "linux-generic-hwe-${ubuntu_version}"; then
      log_info "Installing HWE kernel for Ubuntu $ubuntu_version"
      apt update
      apt install -y "linux-generic-hwe-${ubuntu_version}"
   else
      log_success "HWE kernel is already installed"
   fi
}

# GPU detection functions
detect_gpu() {
   echo -e "\n# Detecting GPU devices"
   
   if ! command -v lspci >/dev/null 2>&1; then
      error_exit "lspci command not found. Install pciutils: apt-get install pciutils"
   fi
   
   local lspci_output
   lspci_output=$(lspci -nn | grep -Ei 'VGA|DISPLAY')
   
   if [ -n "$lspci_output" ]; then
      log_info "Detected GPU device(s):"
      echo "$lspci_output"
      log_success "GPU detected - proceeding with Intel GPU driver installation"
      
      # Set global flag for any GPU found
      HAS_DGPU=1
      return 0
   else
      error_exit "No GPU found. This script installs Intel GPU drivers"
   fi
}

# Repository and package management
configure_kobuk_repository() {
   echo -e "\n# Configuring Intel Kobuk GPU repository"
   
   local repo_file="/etc/apt/sources.list.d/kobuk-team-ubuntu-intel-graphics-noble.sources"
   if [ -e "$repo_file" ] || ls /var/lib/apt/lists/ppa.launchpadcontent.net_kobuk-team_intel-graphics_ubuntu_dists_* >/dev/null 2>&1; then
      log_success "Kobuk repository already configured"
      return 0
   fi
   
   log_info "Adding Intel Kobuk GPU repository"
   
   apt-get update
   apt-get install -y software-properties-common
   
   if add-apt-repository -y ppa:kobuk-team/intel-graphics; then
      log_success "Kobuk repository added successfully"
      apt update
   else
      error_exit "Failed to add Kobuk repository"
   fi
}

install_packages() {
   local packages=("$@")
   local failed=0
   
   log_info "Installing packages: ${packages[*]}"
   
   for package in "${packages[@]}"; do
      [ -z "$package" ] && continue
      
      if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
         log_success "Package '$package' already installed"
         continue
      fi
      
      log_info "Installing $package"
      if ! apt-get install -y "$package"; then
         echo "$S_ERROR Failed to install $package"
         failed=1
      else
         log_success "Successfully installed $package"
      fi
   done
   
   return $failed
}

remove_conflicting_packages() {
   echo -e "\n# Removing conflicting GPU packages"
   
   local conflicting_packages=(
      "level-zero"
      "intel-graphics-compiler"
      "intel-compute-runtime"
      "intel-media-driver"
   )
   
   for pkg in "${conflicting_packages[@]}"; do
      if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
         log_info "Removing conflicting package: $pkg"
         apt-get remove -y "$pkg" || true
      fi
   done
}

# User configuration
configure_user_groups() {
   echo -e "\n# Configuring user groups"
   
   local groups=("video" "render")
   local users=("$USER")
   
   # Add native user if running via sudo
   if [ -n "${SUDO_USER:-}" ]; then
      users+=("$SUDO_USER")
   fi
   
   for user in "${users[@]}"; do
      for group in "${groups[@]}"; do
         if ! id -nG "$user" | grep -q -w "$group"; then
            log_info "Adding user $user to group $group"
            usermod -aG "$group" "$user"
         else
            log_success "User $user already in group $group"
         fi
      done
   done
}

# Main installation functions
install_gpu_drivers() {
   echo -e "\n# Installing Intel Arc GPU drivers"
   
   remove_conflicting_packages
   configure_kobuk_repository
   
   # Update package lists
   apt update
   apt dist-upgrade -y
   
   # Install dependencies
   log_info "Installing dependencies"
   install_packages "${DEPENDENCIES[@]}" || error_exit "Failed to install dependencies"
   
   # Install GPU packages
   log_info "Installing GPU driver packages"
   install_packages "${COMMON_GPU_PACKAGES[@]}" || error_exit "Failed to install GPU packages"
   
   # Install media packages
   log_info "Installing media acceleration packages"
   install_packages "${MEDIA_GPU_PACKAGES[@]}" || error_exit "Failed to install media packages"
   
   # Install optional packages (non-critical)
   log_info "Installing optional packages"
   install_packages "${OPTIONAL_GPU_PACKAGES[@]}" || log_info "Some optional packages failed to install (non-critical)"
   
   configure_user_groups
   
   # Post-installation configuration (previously post_installation_fixes)
   echo -e "\n# Post-installation configuration"
   
   # Verify critical packages
   local critical_packages=("intel-level-zero-gpu" "intel-opencl-icd" "libze-intel-gpu1")
   local missing_packages=()
   
   for pkg in "${critical_packages[@]}"; do
      if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
         log_success "$pkg is installed"
      else
         echo "$S_ERROR $pkg is NOT installed"
         missing_packages+=("$pkg")
      fi
   done
   
   if [ ${#missing_packages[@]} -gt 0 ]; then
      log_info "Reinstalling missing critical packages"
      install_packages "${missing_packages[@]}"
   fi
   
   # Fix DRI device permissions
   if [ -e "/dev/dri" ]; then
      log_info "Checking DRI devices: $(find /dev/dri/ -maxdepth 1 -type f -printf '%f ' 2>/dev/null)"
      
      if ls /dev/dri/render* >/dev/null 2>&1; then
         chmod 666 /dev/dri/render*
         log_success "Updated render device permissions"
      fi
   else
      echo "$S_ERROR /dev/dri directory not found"
   fi
   
   log_success "Intel GPU driver installation and configuration completed"
}

# Verify driver installation
verify_drivers() {
   echo -e "\n# Verifying driver installation"
   
   # OpenCL verification
   if command -v clinfo >/dev/null 2>&1; then
      if clinfo >/dev/null 2>&1; then
         log_success "OpenCL runtime working"
         
         local device_names
         device_names=$(clinfo 2>/dev/null | grep "Device Name" | grep -i intel)
         
         if [ -n "$device_names" ]; then
            log_success "Intel GPU devices detected by OpenCL:"
            echo "$device_names"
            
            if [ "$HAS_DGPU" -eq 1 ] && echo "$device_names" | grep -qi "arc\|bmg\|battlemage\|dg2\|alchemist"; then
               log_success "Intel Arc discrete GPU working with OpenCL"
            fi
         else
            echo "$S_ERROR No Intel GPU devices found in OpenCL"
         fi
      else
         echo "$S_ERROR clinfo failed to run"
      fi
   else
      echo "$S_ERROR clinfo not found"
   fi
}

# Main function
main() {
   local verify_only=0
   check_privileges
   
   echo "Intel GPU Driver Installation Script"
   echo "Supports: Intel Arc discrete GPU and Intel integrated GPU"
   echo "========================================================="
   
   verify_platform
   detect_gpu
   verify_os
   verify_kernel
   
   if [ "$verify_only" -eq 1 ]; then
      verify_drivers
   else
      install_gpu_drivers
      verify_drivers
      echo -e "\n# $S_VALID GPU installation completed. Please reboot your system."
   fi
}

# Execute main function
main "$@"

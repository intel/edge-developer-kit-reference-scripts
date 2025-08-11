#!/bin/bash

# NPU (Neural Processing Unit) Installer
# Standardized NPU installation for Core Ultra family
# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# Global version variables
NPU_VERSION="1.19.0"
NPU_BUILD_ID="20250707-16111289554"
LEVEL_ZERO_VERSION="v1.22.4"
UBUNTU_VERSION="ubuntu24.04"

# Status indicators - using ASCII for better compatibility (conditional definition)
if [[ -z "$S_ERROR" ]]; then
    S_ERROR="[ERROR]"
fi
if [[ -z "$S_VALID" ]]; then
    S_VALID="[✓]"
fi
if [[ -z "$S_WARNING" ]]; then
    S_WARNING="[!]"
fi

# Colors for output (conditional definition)
if [[ -z "$RED" ]]; then
    RED='\033[0;31m'
fi
if [[ -z "$GREEN" ]]; then
    GREEN='\033[0;32m'
fi
if [[ -z "$YELLOW" ]]; then
    YELLOW='\033[1;33m'
fi
if [[ -z "$NC" ]]; then
    NC='\033[0m' # No Color
fi

# Print colored output (define only if not already defined)
if ! command -v print_error &> /dev/null; then
    print_error() { echo -e "${RED}${S_ERROR} $1${NC}"; }
fi
if ! command -v print_success &> /dev/null; then
    print_success() { echo -e "${GREEN}${S_VALID} $1${NC}"; }
fi
if ! command -v print_warning &> /dev/null; then
    print_warning() { echo -e "${YELLOW}${S_WARNING} $1${NC}"; }
fi
if ! command -v print_info &> /dev/null; then
    print_info() { echo -e "$1"; }
fi

# Check if package is actually installed (not just known to dpkg)
is_package_installed() {
   dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# Clean up old NPU packages and conflicting packages
cleanup_old_packages() {
   print_info "Removing old NPU packages and conflicting packages..."
   
   # Remove NPU packages with force to handle conflicts
   dpkg --purge --force-remove-reinstreq intel-driver-compiler-npu intel-fw-npu intel-level-zero-npu 2>/dev/null || true
   
   # Remove conflicting libze1 package
   apt remove -y libze1 2>/dev/null || true
   
   # Fix any broken dependencies
   apt install --fix-broken -y
   
   print_success "Old packages and conflicts cleaned up"
   return 0
}

# Install NPU dependencies
install_dependencies() {
   print_info "Installing NPU dependencies..."
   if ! apt update; then
      print_warning "apt update failed, continuing anyway..."
   fi
   
   if apt install -y libtbb12 wget; then
      print_success "Dependencies installed"
      return 0
   else
      print_error "Failed to install dependencies"
      return 1
   fi
}

# Download NPU driver packages
download_npu_packages() {
   print_info "Downloading NPU driver packages ${NPU_VERSION}..."
   
   local base_url="https://github.com/intel/linux-npu-driver/releases/download/v${NPU_VERSION}"
   local build_suffix="${NPU_VERSION}.${NPU_BUILD_ID}_${UBUNTU_VERSION}_amd64.deb"
   
   # Download each package with error checking
   local files=(
      "intel-driver-compiler-npu_${build_suffix}"
      "intel-fw-npu_${build_suffix}"
      "intel-level-zero-npu_${build_suffix}"
   )
   
   for file in "${files[@]}"; do
      local url="${base_url}/${file}"
      print_info "  Downloading ${file}..."
      if wget -q --timeout=30 "${url}"; then
         print_success "  Downloaded ${file}"
      else
         print_error "  Failed to download ${file} from ${url}"
         return 1
      fi
   done
   
   print_success "All NPU packages downloaded successfully"
   return 0
}

# Check if Level Zero is installed
check_level_zero() {
   print_info "Checking Level Zero installation..."
   if dpkg -l level-zero 2>/dev/null | grep -q "^ii"; then
      print_success "Level Zero is already installed"
      return 0
   else
      print_info "Level Zero not found, will need to install"
      return 1
   fi
}

# Download oneAPI Level Zero package
download_level_zero_package() {
   print_info "Downloading oneAPI Level Zero ${LEVEL_ZERO_VERSION}..."
   local lz_url="https://github.com/oneapi-src/level-zero/releases/download/${LEVEL_ZERO_VERSION}/level-zero_1.22.4+u24.04_amd64.deb"
   
   if wget -q --timeout=30 "${lz_url}"; then
      print_success "Downloaded Level Zero package"
      return 0
   else
      print_error "Failed to download Level Zero from ${lz_url}"
      return 1
   fi
}

# Install NPU packages
install_npu_packages() {
   print_info "Installing NPU driver packages..."
   if dpkg -i ./*.deb; then
      print_success "NPU packages installed successfully"
      return 0
   else
      print_warning "NPU package installation failed, attempting to fix dependencies..."
      if apt install --fix-broken -y && dpkg -i ./*.deb; then
         print_success "NPU packages installed after dependency fix"
         return 0
      else
         print_error "Failed to install NPU packages even after dependency fix"
         return 1
      fi
   fi
}

# Install Level Zero package
install_level_zero_package() {
   print_info "Installing oneAPI Level Zero package..."
   
   if ! dpkg -i ./level-zero*.deb; then
      print_warning "Level Zero installation failed, fixing dependencies..."
      apt install --fix-broken -y
      dpkg -i ./level-zero*.deb
   fi
   
   print_success "Level Zero package installed"
   return 0
}

# Setup device permissions
setup_device_permissions() {
   print_info "Configuring NPU device permissions..."
   
   # Create udev rules
   if echo 'SUBSYSTEM=="accel", KERNEL=="accel*", GROUP="render", MODE="0660"' > /etc/udev/rules.d/10-intel-vpu.rules; then
      print_success "udev rules created"
   else
      print_error "Failed to create udev rules"
      return 1
   fi
   
   # Reload udev rules
   udevadm control --reload-rules
   udevadm trigger --subsystem-match=accel
   
   print_success "Device permissions configured"
   return 0
}

# Check NPU device and dmesg
check_npu_device() {
   print_info "Checking NPU device availability..."
   
   if ls /dev/accel/accel0 1>/dev/null 2>&1; then
      print_success "NPU device found: /dev/accel/accel0"
      
      # Show device permissions
      print_info "Device permissions:"
      ls -lah /dev/accel/accel0 2>/dev/null || true
      
      # Check dmesg for intel_vpu state
      print_info "Checking dmesg for intel_vpu messages..."
      dmesg | grep -i "intel_vpu\|npu" | tail -5 || print_info "No recent intel_vpu messages found"
      
      return 0
   else
      print_warning "NPU device not found - reboot may be required"
      return 1
   fi
}

# Verify NPU installation
verify_installation() {
   print_info "Verifying NPU installation..."
   
   # Check NPU packages
   local npu_packages=("intel-driver-compiler-npu" "intel-fw-npu" "intel-level-zero-npu")
   local all_npu_installed=true
   
   for pkg in "${npu_packages[@]}"; do
      if is_package_installed "$pkg"; then
         print_success "Package $pkg installed"
      else
         print_error "Package $pkg not installed"
         all_npu_installed=false
      fi
   done
   
   # Check Level Zero packages (either generic or NPU-specific)
   if is_package_installed "level-zero"; then
      print_success "oneAPI Level Zero installed"
   elif is_package_installed "intel-level-zero-npu"; then
      print_success "NPU Level Zero installed"
   else
      print_error "No Level Zero package found"
   fi
   
   # Check NPU device and dmesg
   check_npu_device
   
   # Check udev rules
   if [ -f "/etc/udev/rules.d/10-intel-vpu.rules" ]; then
      print_success "NPU udev rules configured"
   else
      print_error "NPU udev rules not found"
   fi
   
   print_info ""
   print_info "Installation verification completed"
   if [ "$all_npu_installed" = true ]; then
      print_success "All NPU components installed successfully"
   else
      print_warning "Some NPU components may not be installed correctly"
   fi
}

# Main installation function
install_npu() {
   print_info "Starting NPU installation for Core Ultra platform..."
   print_info "NPU Version: ${NPU_VERSION} | Build: ${NPU_BUILD_ID}"
   print_info "Level Zero Version: ${LEVEL_ZERO_VERSION}"
   print_info ""
   
   # Validate required variables
   if [[ -z "$NPU_VERSION" || -z "$NPU_BUILD_ID" || -z "$LEVEL_ZERO_VERSION" ]]; then
      print_error "Required version variables not set"
      exit 1
   fi
   
   # Check if running as root
   if [ "$EUID" -ne 0 ]; then
      print_error "This script must be run as root (use sudo)"
      exit 1
   fi
   
   # Create temporary directory
   local temp_dir="/tmp/npu_installer_$$"
   mkdir -p "$temp_dir"
   cd "$temp_dir" || { print_error "Failed to create/enter temp directory"; exit 1; }
   
   # Installation steps
   print_info "Step 1: Cleaning up old packages and conflicts..."
   cleanup_old_packages || { print_error "Failed to cleanup old packages"; exit 1; }
   
   print_info "Step 2: Installing dependencies..."
   install_dependencies || { print_error "Failed to install dependencies"; exit 1; }
   
   print_info "Step 3: Downloading NPU packages..."
   download_npu_packages || { print_error "Failed to download NPU packages"; exit 1; }
   
   print_info "Step 4: Installing NPU packages..."
   install_npu_packages || { print_error "Failed to install NPU packages"; exit 1; }
   
   print_info "Step 5: Checking Level Zero installation..."
   if ! check_level_zero; then
      print_info "Step 6: Downloading Level Zero package..."
      download_level_zero_package || { print_error "Failed to download Level Zero package"; exit 1; }
      
      print_info "Step 7: Installing Level Zero package..."
      install_level_zero_package || { print_error "Failed to install Level Zero package"; exit 1; }
   else
      print_info "Step 6-7: Level Zero already installed, skipping download and installation"
   fi
   
   print_info "Step 8: Setting up device permissions..."
   setup_device_permissions || { print_error "Failed to setup device permissions"; exit 1; }
   
   # Cleanup
   print_info "Step 9: Cleaning up temporary files..."
   cd / || exit 1
   rm -rf "$temp_dir"
   print_success "Cleanup completed"

   # Verify installation
   print_info "Step 10: Verifying installation..."
   verify_installation
   
   print_info ""
   print_success "NPU installation completed"
   print_info ""
   print_warning "System reboot is recommended for NPU to be fully functional"
   print_info "After reboot, verify with: ls /dev/accel/accel0"
   print_info "Expected output: crw-rw---- 1 root render 261, 0 <date> /dev/accel/accel0"
   print_info "Also check dmesg for intel_vpu messages: dmesg | grep intel_vpu"
   print_info ""
}

# Run installation if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
   install_npu
fi

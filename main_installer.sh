#!/bin/bash

# Main Intel Platform Installer
# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# NPU Driver Version Information
# https://github.com/intel/linux-npu-driver/releases/tag/v1.19.0
export NPU_VERSION="v1.19.0"
export NPU_BUILD_ID="20250707-16111289554"
export NPU_COMMIT_ID="0deed959591f2c3868781bcd5210c67861953f08"
export LEVEL_ZERO_VERSION="v1.22.4"

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Status indicators
S_ERROR="❌"
S_VALID="✅"
S_WARNING="⚠️"

# Default values
export INSTALL_CAMERA=false
export INSTALL_OPENVINO=false

# Log file configuration
LOG_FILE="/var/log/intel-platform-installer.log"

# Initialize logging
setup_logging() {
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Rotate existing log file if it's too large (>10MB)
    if [ -f "$LOG_FILE" ] && [ "$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)" -gt 10485760 ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        echo "Previous log file rotated to ${LOG_FILE}.old"
    fi
    
    # Create/clear log file with timestamp header
    {
        echo "========================================================================"
        echo "Intel Platform Installer Log"
        echo "========================================================================"
        echo "Installation started: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Script: $0"
        echo "Arguments: $*"
        echo "User: $(whoami)"
        echo "Working Directory: $(pwd)"
        echo "System Info: $(uname -a)"
        echo "========================================================================"
        echo ""
    } > "$LOG_FILE"
    
    # Ensure log file has proper permissions
    chmod 644 "$LOG_FILE"
    
    # Set up output redirection to both terminal and log file
    exec > >(tee -a "$LOG_FILE")
    exec 2>&1
    
    echo "$S_VALID Logging initialized: $LOG_FILE"
}

# Usage function
usage() {
    echo "Intel Platform Installer"
    echo "========================"
    echo ""
    echo "Usage: $0"
    echo ""
    echo "Supported OS: Ubuntu 24.04 LTS with kernel 6.11.x (HWE) only"
    echo ""
    echo "Installation Flow:"
    echo "  Xeon:       Skip setup → Ubuntu 24 Server guide"
    echo "  Core Ultra: NPU → GPU (if Arc GPU present) → OpenVINO"
    echo "  Atom/Core:  GPU (if Arc GPU present) → OpenVINO"
}

# Check if running with appropriate privileges
check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        echo "$S_ERROR This script must be run with sudo or as root user"
        exit 1
    fi
}

# Verify Ubuntu 24.04 LTS with Canonical kernel
verify_ubuntu_24() {
    echo "# Verifying Ubuntu 24.04 LTS with Canonical kernel..."
    
    # Check OS release
    if [ ! -f /etc/os-release ]; then
        echo "$S_ERROR /etc/os-release file not found"
        exit 1
    fi
    
    # shellcheck disable=SC1091
    source /etc/os-release
    
    # Check Ubuntu version
    if [ "$ID" != "ubuntu" ] || [ "$VERSION_ID" != "24.04" ]; then
        echo "$S_ERROR This installer requires Ubuntu 24.04 LTS"
        echo "Current OS: $PRETTY_NAME"
        echo "Please upgrade to Ubuntu 24.04 LTS before running this script"
        exit 1
    fi

   # Check kernel version (Ubuntu 24.04 LTS - require 6.11.x or 6.14.x only)
   local kernel_major
   local kernel_minor
   kernel_major=$(uname -r | cut -d'.' -f1)
   kernel_minor=$(uname -r | cut -d'.' -f2)

   # Check if HWE stack is installed
   if ! { [ "$kernel_major" = "6" ] && { [ "$kernel_minor" = "11" ] || [ "$kernel_minor" = "14" ]; }; }; then
      echo "$S_WARNING Unsupported kernel version: $(uname -r)"
      echo "This installer requires kernel 6.11.x or 6.14.x (HWE)"
      echo "If you have a non-HWE kernel installed, HWE kernel will be installed now."
      echo "Attempting to install HWE kernel (linux-generic-hwe-24.04)..."
      apt update
      apt install -y linux-generic-hwe-24.04
      echo "$S_VALID HWE kernel installed. Please reboot and run this installer again."
      exit 0
   fi

   echo "$S_VALID Ubuntu 24.04 LTS with kernel 6.11.x or 6.14.x detected"
   echo "$S_VALID Ubuntu 24.04 LTS with Canonical kernel verified"
}

# Install NPU drivers (Core Ultra only)
install_npu_drivers() {
    echo "Installing NPU drivers for Core Ultra..."
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/npu_installer.sh"
    install_npu
}

# Check for Intel Arc GPU presence
check_intel_arc_gpu() {
    echo "# Checking for Intel Arc GPU..."
    
    # Check if lspci is available
    if ! command -v lspci >/dev/null 2>&1; then
        echo "$S_WARNING lspci command not found. Installing pciutils..."
        apt-get update && apt-get install -y pciutils
    fi
    
    # Intel Arc GPU PCI IDs (BMG/DG2)
    local arc_pci_ids=(
        # Battlemage (BMG)
        "8086:e20b" "8086:e20c" "8086:5690" "8086:e211"
        # Alchemist (DG2, Xe-HPG)
        "8086:5690" "8086:5691" "8086:5696" "8086:5692" "8086:5697"
        "8086:5693" "8086:5694" "8086:56a0" "8086:56a1" "8086:56a2"
        "8086:56a5" "8086:56a6" "8086:56b3" "8086:56b2" "8086:56b1"
        "8086:56b0" "8086:56ba" "8086:56bc" "8086:56bd" "8086:56bb"
    )
    
    # Find Intel VGA/DISPLAY devices
    local lspci_output
    lspci_output=$(lspci -nn | grep -Ei 'VGA|DISPLAY' | grep Intel)
    
    if [ -z "$lspci_output" ]; then
        echo "$S_WARNING No Intel GPU devices detected"
        return 1
    fi
    
    # Check for Intel Arc GPUs specifically
    local found_arc_gpu=false
    while IFS= read -r line; do
        for pci_id in "${arc_pci_ids[@]}"; do
            if echo "$line" | grep -q "$pci_id"; then
                echo "$S_VALID Intel Arc GPU detected: $pci_id"
                found_arc_gpu=true
                break
            fi
        done
    done <<< "$lspci_output"
    
    if [ "$found_arc_gpu" = true ]; then
        echo "$S_VALID Intel Arc GPU found - GPU drivers will be installed"
        return 0
    else
        echo "$S_WARNING No Intel Arc GPU detected - only iGPU present"
        echo "GPU driver installation will be skipped"
        return 1
    fi
}

# Install GPU drivers (DG2/BMG cards) - only if Arc GPU is present
install_gpu_drivers() {
    if check_intel_arc_gpu; then
        echo "Installing GPU drivers (DG2/BMG cards)..."
        # shellcheck disable=SC1091
        source "$SCRIPT_DIR/gpu_installer.sh"
        echo "$S_VALID GPU drivers installed"
    else
        echo "$S_WARNING Skipping GPU driver installation - no Intel Arc GPU detected"
        echo "System will use integrated graphics (iGPU) only"
    fi
}

install_openvino(){
      echo ""
      echo "========================================================================"
      echo "# Installing OpenVINO toolkit..."
      echo "========================================================================"
      
      if [ -f "$SCRIPT_DIR/openvino_installer.sh" ]; then
         echo "Found OpenVINO installer at: $SCRIPT_DIR/openvino_installer.sh"
         echo "Starting OpenVINO installation process..."
         
         if bash "$SCRIPT_DIR/openvino_installer.sh"; then
            echo ""
            echo "$S_VALID OpenVINO toolkit installed successfully"
            
            # Verify installation by checking if virtual environment exists
            if [ -d "/opt/intel/openvino_env" ]; then
               echo "$S_VALID OpenVINO virtual environment confirmed at /opt/intel/openvino_env"
               
               # Additional verification - check if OpenVINO can be imported
               if /opt/intel/openvino_env/bin/python -c "import openvino" 2>/dev/null; then
                  echo "$S_VALID OpenVINO Python package verified and importable"
               else
                  echo "$S_WARNING OpenVINO Python package may not be properly installed"
               fi
            else
               echo "$S_WARNING OpenVINO virtual environment not found at /opt/intel/openvino_env"
            fi
         else
            local exit_code=$?
            echo ""
            echo "$S_ERROR OpenVINO installation failed"
            echo "Exit code: $exit_code"
            echo "Please check the installation logs for details"
            echo "Log file location: /var/log/intel-platform-installer.log"
            return 1
         fi
      else
         echo "$S_ERROR OpenVINO installer not found at $SCRIPT_DIR/openvino_installer.sh"
         echo "Expected location: $SCRIPT_DIR/openvino_installer.sh"
         echo "Current directory: $(pwd)"
         echo "Available files in $SCRIPT_DIR:"
         ls -la "$SCRIPT_DIR"/*.sh 2>/dev/null || echo "No .sh files found"
         return 1
      fi
      
      echo "========================================================================"
}

summary(){
      echo "Running Installation Summary"
      # shellcheck disable=SC1091
      source "$SCRIPT_DIR/print_summary_table.sh"
}

# Main execution flow
main() {
    check_privileges
    setup_logging "$@"
    
    echo "Intel Platform Installer"
    echo "========================"
    echo ""
    
    # 1. Verify Ubuntu 24.04 LTS with Canonical kernel
    verify_ubuntu_24
    echo ""
    
    # 2. Load platform detection
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/platform_detection.sh"
    
    # 3. Detect platform and OS
    echo "# Detecting platform and OS..."
    detect_platform
    detect_os
    echo ""
    
    # 4. Platform Installation Flow
    echo "# Platform Installation Flow..."
    echo "$S_VALID Platform detected: $CPU_MODEL"
    
    # Determine platform family and execute appropriate flow
    if is_xeon; then
        echo "# Xeon platform detected"
        echo "$S_ERROR Setup skipped for Xeon platforms"
        echo "Please follow Ubuntu 24.04 Server installation guide:"
        echo "https://ubuntu.com/download/server"
        echo "For Xeon-specific optimizations, consult Intel documentation"
        
    elif is_coreultra; then
        echo "# Core Ultra platform detected"
        echo "Installation sequence: NPU → GPU (if present) → OpenVINO"
        
        # Core Ultra flow: NPU → GPU (conditional) → OpenVINO
        install_npu_drivers
        install_gpu_drivers  # Will check for Arc GPU presence first
        
        # Install OpenVINO with error handling
        if ! install_openvino; then
            echo "$S_ERROR Core Ultra platform setup incomplete due to OpenVINO installation failure"
            echo "NPU and GPU drivers were installed successfully"
            echo "You may retry OpenVINO installation manually: bash $SCRIPT_DIR/openvino_installer.sh"
        fi
        
    else
        echo "# Atom/Core platform detected"
        echo "Installation sequence: GPU (if present) → OpenVINO"
        
        # Atom/Core flow: GPU (conditional) → OpenVINO
        install_gpu_drivers  # Will check for Arc GPU presence first
        
        # Install OpenVINO with error handling
        if ! install_openvino; then
            echo "$S_ERROR Atom/Core platform setup incomplete due to OpenVINO installation failure"
            echo "GPU drivers were installed successfully (if Arc GPU was present)"
            echo "You may retry OpenVINO installation manually: bash $SCRIPT_DIR/openvino_installer.sh"
        fi
    fi
    
   #  # 5. Optional camera installation
   #  if [ "$INSTALL_CAMERA" = true ]; then
   #      echo ""
   #      echo "# Installing camera drivers..."
   #      # shellcheck source=$SCRIPT_DIR/camera_installer.sh
   #      source "$SCRIPT_DIR/camera_installer.sh"
   #      install_camera_drivers
   #  fi  
   #  echo ""
   #  echo "$S_VALID Platform installation completed - Done"
   #  echo "System reboot may be required for all changes to take effect"
   summary
   
   # Log completion
   echo ""
   echo "========================================================================"
   echo "Installation completed: $(date '+%Y-%m-%d %H:%M:%S')"
   echo "Log file saved: $LOG_FILE"
   echo "========================================================================"
}

# Execute main function with all arguments
main "$@"

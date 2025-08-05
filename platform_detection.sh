#!/bin/bash

# Platform Detection Module
# Detects Intel platforms, OS compatibility, and hardware features
# SPDX-License-Identifier: Apache-2.0
# Copyright (C) 2025 Intel Corporation

# Status indicators
S_ERROR="❌"

# Global variables
PLATFORM_FAMILY=""
CPU_MODEL=""
IS_COREULTRA=false
HAS_CAMERA=false
HAS_GPU=false

# Detect platform information
detect_platform() {
    echo "Detecting platform family..."

    # Get CPU model
    CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^[ \t]*//' || echo "unknown")
    
    # Detect platform family
    if echo "$CPU_MODEL" | grep -qi "ultra"; then
        PLATFORM_FAMILY="coreultra"
        IS_COREULTRA=true
    elif echo "$CPU_MODEL" | grep -qi "xeon"; then
        PLATFORM_FAMILY="xeon"
    elif echo "$CPU_MODEL" | grep -qi "atom" || echo "$CPU_MODEL" | grep -qiE "core.*[0-9]+\s+N[0-9]+"; then
        PLATFORM_FAMILY="atom"
    elif echo "$CPU_MODEL" | grep -qi "core"; then
        PLATFORM_FAMILY="core"
    elif echo "$CPU_MODEL" | grep -qi "processor"; then
        PLATFORM_FAMILY="processor"
    else
        PLATFORM_FAMILY="unknown"
    fi
    
    echo "  CPU Model: $CPU_MODEL"
    echo "  Platform Family: $PLATFORM_FAMILY"
    
    # Detect hardware features
    detect_hardware_features
}

# Detect hardware features
detect_hardware_features() {
    echo "Detecting hardware features..."
    
    # Check for cameras
    #if ls /dev/video* 1>/dev/null 2>&1; then
    #    HAS_CAMERA=true
    #    echo "  Camera: Detected"
    #else
    #    echo "  Camera: Not detected"
    #fi
    
    # Check for Intel GPU
    if lspci | grep -i "vga\|display" | grep -i intel >/dev/null 2>&1; then
        HAS_GPU=true
        echo "  Intel GPU: Detected"
    else
        echo "  Intel GPU: Not detected"
    fi
}

# Check OS compatibility
detect_os() {
    echo "Checking OS compatibility..."
    
    if [ ! -f /etc/os-release ]; then
        echo "$S_ERROR /etc/os-release file not found"
        exit 1
    fi
    
    # shellcheck disable=SC1091
    . /etc/os-release
    
    if [[ "$ID" != "ubuntu" ]]; then
        echo "$S_ERROR Only Ubuntu is supported. Detected: $ID"
        exit 1
    fi
    
    if [[ "$VERSION_ID" != "24.04" ]]; then
        echo "$S_ERROR Only Ubuntu 24.04 LTS is supported. Detected: $VERSION_ID"
        exit 1
    fi
    
    echo "  OS: $PRETTY_NAME ✓"
}

# Check if platform is market-ready
is_market_ready() {
    local platforms_file="$SCRIPT_DIR/platforms.txt"
    
    if [ -f "$platforms_file" ]; then
        # Check CPU_MODEL against the platforms list
        # The platforms.txt contains patterns like "Intel(R) Core(TM) Ultra 9", "Core Ultra 7", etc.
        while IFS= read -r platform_pattern; do
            # Skip comment lines and empty lines
            [[ "$platform_pattern" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$platform_pattern" ]] && continue
            
            # Check if CPU_MODEL contains the platform pattern
            if echo "$CPU_MODEL" | grep -qi "$platform_pattern"; then
                return 0  # Market-ready platform found
            fi
        done < "$platforms_file"
        
        # Platform not found in market-ready list
        return 1
    else
        # Default to market-ready if config file doesn't exist
        return 0
    fi
}

# Check if Core Ultra platform
is_coreultra() {
    [ "$IS_COREULTRA" = true ]
}

# Check if Xeon platform
is_xeon() {
    [ "$PLATFORM_FAMILY" = "xeon" ]
}

# Check if Atom platform
is_atom() {
    [ "$PLATFORM_FAMILY" = "atom" ]
}

# Check if traditional Core platform
is_core() {
    [ "$PLATFORM_FAMILY" = "core" ]
}

# Check if Processor platform
is_processor() {
    [ "$PLATFORM_FAMILY" = "processor" ]
}

# Check if camera is present
has_camera() {
    [ "$HAS_CAMERA" = true ]
}

# Check if GPU is present
has_gpu() {
    [ "$HAS_GPU" = true ]
}

# Auto-install logic for NPU (Core Ultra platforms)
is_auto_install_npu() {
    [ "$IS_COREULTRA" = true ]
}

# Auto-install logic for OpenVINO (Core Ultra platforms with camera)
is_auto_install_openvino() {
    [ "$IS_COREULTRA" = true ] && [ "$HAS_CAMERA" = true ]
}

# Auto-install logic for camera drivers
is_auto_install_camera() {
    [ "$HAS_CAMERA" = true ]
}

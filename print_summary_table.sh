#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# Copyright (C) 2025 Intel Corporation

# Print a summary table of system installation status

# Status indicators - using ASCII for better compatibility (conditional definition)
if [[ -z "$S_ERROR" ]]; then
    S_ERROR="[ERROR]"
fi
if [[ -z "$S_VALID" ]]; then
    S_VALID="[✓]"
fi

printf "\n==================== System Installation Summary ====================\n"

# Kernel version
KERNEL_VERSION=$(uname -r)

# HWE stack detection
if dpkg -l | grep -q 'linux-generic-hwe'; then
    HWE_STACK="Installed"
else
    HWE_STACK="Not Installed"
fi

# Ubuntu version
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    UBUNTU_VERSION="$PRETTY_NAME"
else
    UBUNTU_VERSION="Unknown"
fi

# NPU detection and version
NPU_PKG=$(dpkg -l | grep 'intel-level-zero-npu' | awk '{print $2}')
NPU_VER=$(dpkg -l | grep 'intel-level-zero-npu' | awk '{print $3}')
if [ -n "$NPU_PKG" ]; then
    NPU_STATUS="Detected"
else
    NPU_STATUS="Not Detected"
fi

# Related NPU packages and their versions
PKG_LIST="intel-driver-compiler-npu intel-fw-npu intel-level-zero-npu level-zero"
declare -A PKG_VERSIONS
for pkg in $PKG_LIST; do
    # Get all installed versions for the package, comma-separated
    vers=$(dpkg -l | awk '$2 ~ /^'"$pkg"'/ {print $3}' | paste -sd "," -)
    PKG_VERSIONS[$pkg]=$vers
done

# GPU info
GPU_TYPE="Not Detected"
GPU_INFO="-"
GPU_DRIVER="-"
GPU_DEVICES=""
if lspci | grep -i 'vga\|3d\|display' | grep -i intel >/dev/null; then
    GPU_TYPE="Intel"
    INTEL_GPU_COUNT=$(lspci | grep -i 'vga\|3d\|display' | grep -i -c intel)
    GPU_INFO="$INTEL_GPU_COUNT Intel graphics device(s) detected"
    # Get i915 driver info from lsmod if available
    if lsmod | grep -q i915; then
        GPU_DRIVER="i915 (loaded)"
    else
        GPU_DRIVER="i915 (not loaded)"
    fi
    # Store all GPU devices for detailed listing
    GPU_DEVICES=$(lspci | grep -i 'vga\|3d\|display' | grep -i intel)
elif lspci | grep -i 'vga\|3d\|display' | head -n1 | grep -q .; then
    GPU_TYPE="Other"
    GPU_INFO=$(lspci | grep -i 'vga\|3d\|display' | head -n1)
    GPU_DEVICES=$(lspci | grep -i 'vga\|3d\|display')
fi

# Print table
printf "%-25s | %-40s\n" "Item" "Value"
printf "%-25s-+-%-40s\n" "------------------------" "----------------------------------------"
printf "%-25s | %-40s\n" "Kernel Version" "$KERNEL_VERSION"
printf "%-25s | %-40s\n" "HWE Stack" "$HWE_STACK"
printf "%-25s | %-40s\n" "Ubuntu Version" "$UBUNTU_VERSION"
printf "%-25s | %-40s\n" "NPU Status" "$NPU_STATUS"
printf "%-25s | %-40s\n" "NPU Package" "${NPU_PKG:-"-"}"
printf "%-25s | %-40s\n" "NPU Version" "${NPU_VER:-"-"}"
for pkg in $PKG_LIST; do
    printf "%-25s | %-40s\n" "$pkg" "${PKG_VERSIONS[$pkg]:-"-"}"
done
printf "%-25s | %-40s\n" "GPU Type" "$GPU_TYPE"
printf "%-25s | %-40s\n" "GPU Count" "$GPU_INFO"
printf "%-25s | %-40s\n" "GPU Driver" "${GPU_DRIVER:-"-"}"

# Print each GPU device on separate lines
if [ -n "$GPU_DEVICES" ]; then
    device_num=1
    while IFS= read -r device; do
        if [ -n "$device" ]; then
            printf "%-25s | %-40s\n" "GPU Device $device_num" "$device"
            ((device_num++))
        fi
    done <<< "$GPU_DEVICES"
fi

# Print Intel graphics packages if Intel GPU detected
if [ "$GPU_TYPE" = "Intel" ]; then
    INTEL_PACKAGES=$(dpkg -l | grep -i 'intel.*graphics\|mesa\|xserver-xorg-video-intel\|intel-media-va-driver\|intel-opencl-icd\|i965-va-driver' 2>/dev/null | head -5)
    if [ -n "$INTEL_PACKAGES" ]; then
        printf "%-25s-+-%-40s\n" "------------------------" "----------------------------------------"
        printf "%-25s | %-40s\n" "Intel Graphics Packages" ""
        printf "%-25s-+-%-40s\n" "------------------------" "----------------------------------------"
        package_num=1
        while IFS= read -r package; do
            if [ -n "$package" ]; then
                # Extract package name and version
                pkg_name=$(echo "$package" | awk '{print $2}')
                pkg_version=$(echo "$package" | awk '{print $3}')
                printf "%-25s | %-40s\n" "$pkg_name" "$pkg_version"
                ((package_num++))
            fi
        done <<< "$INTEL_PACKAGES"
    fi
fi

# Validate platform configuration
validate_configuration() {
    local validation_passed=true
    local missing_items=()
    
    # Check kernel version
    if [ -z "$KERNEL_VERSION" ] || [ "$KERNEL_VERSION" = "unknown" ]; then
        validation_passed=false
        missing_items+=("Kernel Version")
    fi
    
    # Check Ubuntu version
    if [ -z "$UBUNTU_VERSION" ] || [ "$UBUNTU_VERSION" = "Unknown" ]; then
        validation_passed=false
        missing_items+=("Ubuntu Version")
    fi
    
    # Check HWE stack detection
    if [ -z "$HWE_STACK" ]; then
        validation_passed=false
        missing_items+=("HWE Stack Status")
    fi
    
    # Check GPU detection
    if [ -z "$GPU_TYPE" ] || [ "$GPU_TYPE" = "Not Detected" ]; then
        validation_passed=false
        missing_items+=("GPU Detection")
    fi
    
    # Check if at least basic system info is available
    if [ ! -f /etc/os-release ]; then
        validation_passed=false
        missing_items+=("OS Release Information")
    fi
    
    # Display validation result
    printf "%-25s-+-%-40s\n" "------------------------" "----------------------------------------"
    if [ "$validation_passed" = true ]; then
        printf "%-25s | %-40s\n" "Platform Status" "$S_VALID Platform is configured"
    else
        printf "%-25s | %-40s\n" "Platform Status" "$S_ERROR Incorrect platform configuration"
        if [ ${#missing_items[@]} -gt 0 ]; then
            printf "%-25s | %-40s\n" "Missing/Invalid Items" "$(IFS=', '; echo "${missing_items[*]}")"
        fi
    fi
}

# Run validation
validate_configuration

printf "=====================================================================\n"

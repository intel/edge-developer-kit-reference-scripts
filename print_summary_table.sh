#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# Copyright (C) 2025 Intel Corporation

# Print a summary table of system installation status

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
if lspci | grep -i 'vga\|3d\|display' | grep -i intel >/dev/null; then
    GPU_TYPE="Intel"
    GPU_INFO=$(lspci | grep -i 'vga\|3d\|display' | grep -i intel | head -n1)
    GPU_DRIVER=$(modinfo i915 2>/dev/null | grep '^version:' | awk '{print $2}')
elif lspci | grep -i 'vga\|3d\|display' | head -n1 | grep -q .; then
    GPU_TYPE="Other"
    GPU_INFO=$(lspci | grep -i 'vga\|3d\|display' | head -n1)
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
printf "%-25s | %-40s\n" "GPU Info" "$GPU_INFO"
printf "%-25s | %-40s\n" "GPU Driver" "${GPU_DRIVER:-"-"}"
printf "=====================================================================\n"

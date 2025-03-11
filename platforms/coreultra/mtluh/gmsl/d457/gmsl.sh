#!/bin/bash
# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -e

test(){
   rm -rf wget*
   sudo rm /usr/share/keyrings/oneapi-archive-keyring.gpg
   sudo rm /etc/apt/sources.list.d/oneAPI.list
   sudo rm /etc/apt/preferences.d/oneapi
   sudo rm /usr/share/keyrings/ros-archive-keyring.gpg
   lsmod | grep intel_ipu6
   sudo rmmod intel_ipu6 intel_ipu6_psys intel_ipu6_isys
   sudo apt purge ros-jazzy-librealsense2-tools
}

verify_os() {
    echo -e "\n# Verifying operating system"
    if [ ! -e /etc/os-release ]; then
        echo "Error: /etc/os-release file not found"
        exit 1
    fi
    VERSION_CODENAME=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d'=' -f2- | tr -d '"')
}

setup_eci_ros() {
    echo -e "Setting up ECI apt repository..."
    sudo gpg --output /etc/apt/trusted.gpg.d/oneapi-archive-keyring.gpg --dearmor GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
    sudo gpg --output /usr/share/keyrings/eci-archive-keyring.gpg --dearmor GPG-PUB-KEY-INTEL-ECI.gpg
    verify_os
    echo "deb [signed-by=/usr/share/keyrings/eci-archive-keyring.gpg] https://eci.intel.com/repos/${VERSION_CODENAME} isar main" | sudo tee /etc/apt/sources.list.d/eci.list
    echo "deb-src [signed-by=/usr/share/keyrings/eci-archive-keyring.gpg] https://eci.intel.com/repos/${VERSION_CODENAME} isar main" | sudo tee -a /etc/apt/sources.list.d/eci.list
    sudo bash -c 'echo -e "Package: *\nPin: origin eci.intel.com\nPin-Priority: 1000" > /etc/apt/preferences.d/isar'
    sudo bash -c 'echo -e "\nPackage: libflann*\nPin: version 1.19.*\nPin-Priority: -1\n\nPackage: flann*\nPin: version 1.19.*\nPin-Priority: -1" >> /etc/apt/preferences.d/isar'
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
    sudo bash -c 'echo -e "Package: intel-oneapi-runtime-*\nPin: version 2024.1.*\nPin-Priority: 1001" > /etc/apt/preferences.d/oneapi'
    # add signed entry to APT sources and configure the APT client to use OpenVINO repository:
    sudo bash -c 'echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/openvino/2023 ubuntu22 main" > /etc/apt/sources.list.d/intel-openvino-2023.list'
    sudo bash -c 'echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/openvino/2024 ubuntu22 main" > /etc/apt/sources.list.d/intel-openvino-2024.list'
    echo -e "Setting up ROS Humble apt repository..."
    #  download the key to system keyring
    sudo -E wget -O- https://raw.githubusercontent.com/ros/rosdistro/master/ros.key | sudo tee /usr/share/keyrings/ros-archive-keyring.gpg > /dev/null
    #  add signed entry to APT sources and configure the APT client to use ROS repository:
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu ${VERSION_CODENAME} main" | sudo tee /etc/apt/sources.list.d/ros2.list
    echo "Setting up ROS Humble apt repository..."
    sudo apt update
}

enable_igc() {
    # Update GRUB configuration
    sudo sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/"$/ i915.enable_guc=3"/' /etc/default/grub.d/09_eci-default.cfg
    sudo update-grub
    # Install linux-firmware
    sudo apt install -y linux-firmware
    # Prompt to reboot the system
    echo "Please reboot the system and rerun the script."

    # Check for i915 messages in dmesg after reboot
    if dmesg | grep -q 'i915.*GUC: submission enabled'; then
        echo "i915 messages found, no need to reboot."
    else
        # Reinstall linux-firmware and prompt to reboot again
        sudo apt install -y linux-firmware
        echo "Please reboot the system and rerun the script."
    fi
}

install_ipu6() {
    echo -e "\n Install Linux headers and intel_ipu6 DKMS Debian packages.."
    sudo apt install linux-firmware
    sudo apt install -y pahole "linux-headers-$(uname -r)" intel-ipu6-dkms

    # Check DKMS status
    DKMS_STATUS="$(dkms status | grep 'ipu6-drivers')"  # Quote the assignment

    if echo "$DKMS_STATUS" | grep -q 'installed'; then
        echo "DKMS driver installed successfully."
        sudo usermod -a -G video "$USER"
        sudo usermod -a -G render "$USER"
    else
        echo "DKMS driver install incomplete. Attempting to force install the DKMS driver."
        # Force install the DKMS driver
        sudo dkms install --force ipu6-drivers/20240118+iotgipu6-0eci*

        # Re-check DKMS status
        DKMS_STATUS="$(dkms status | grep 'ipu6-drivers')"  # Quote again

        if echo "$DKMS_STATUS" | grep -q 'installed'; then
            echo "DKMS driver installed successfully after force install."
            sudo usermod -a -G video "$USER"
            sudo usermod -a -G render "$USER"
        else
            echo "DKMS driver install failed. Please check the installation logs and try again."
            return 1
        fi
    fi
}

ros2_setup() {
    echo "Enable ROS2 Intel® RealSense™ Depth Camera D457 GMSL"
    echo "Installing ROS2 Jazzy Jalisco for Ubuntu 24.04"

    # Install ros-jazzy-librealsense2-tools
    if sudo apt install -y ros-jazzy-librealsense2-tools; then
        echo "ros-jazzy-librealsense2-tools installed successfully."
        return
    fi

    echo "Encountered dependency issue. Attempting to resolve..."
    check_available_versions
    install_highest_version

    # Retry installing ros-jazzy-librealsense2-tools
    if ! sudo apt install -y ros-jazzy-librealsense2-tools; then
        echo "Failed to install ros-jazzy-librealsense2-tools. Please check the dependencies and try again."
        exit 1
    fi

    echo "Ensure system-udevd daemon Intel® RealSense™ ROS2 rules exist"
    # cat /lib/udev/rules.d/99-realsense-d4xx-mipi-dfu.rules
}

check_available_versions() {
    echo "Checking available versions of ros-jazzy-librealsense2..."
    apt-cache policy ros-jazzy-librealsense2
}

install_highest_version() {
    REQUIRED_VERSION=$(apt-cache madison ros-jazzy-librealsense2 | awk '{print $3}' | sort -V | tail -n 1)
    echo "Highest available version of ros-jazzy-librealsense2 is $REQUIRED_VERSION"
    
    echo "Installing ros-jazzy-librealsense2 version $REQUIRED_VERSION..."
    if ! sudo apt install -y "ros-jazzy-librealsense2=$REQUIRED_VERSION"; then
        echo "Failed to install ros-jazzy-librealsense2 version $REQUIRED_VERSION. Please check the repository and try again."
        exit 1
    fi

    verify_installation
}

verify_installation() {
    if dpkg -l | grep -q "ros-jazzy-librealsense2.*$REQUIRED_VERSION"; then
        echo "ros-jazzy-librealsense2 version $REQUIRED_VERSION installed successfully."
    else
        echo "Failed to install ros-jazzy-librealsense2 version $REQUIRED_VERSION. Please check the repository and try again."
        exit 1
    fi
}

kernel_print () {
   sudo dmesg -n 7
   sudo modprobe intel-ipu6-isys
   sudo dmesg | grep -e ipu6 -e d4xx -e max929
   # Check dmesg for IPU6 errors
    if sudo dmesg | grep -q -e "FW authentication failed(-5)"; then
        echo "FW authentication failed(-5) error found. Please replace firmware..."
        exit 1
        # Define the directory for cloning the repository
    else
        echo "No FW authentication error found in dmesg."
    fi
}

main() {
   #test
   setup_eci_ros
   install_ipu6
   ros2_setup
   kernel_print
}
main

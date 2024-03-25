#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -e

# symbol
S_VALID="✓"
#S_INVALID="✗"

# verify current user
if [ "$EUID" -eq 0 ]; then
    echo "Must not run with sudo or root user"
    exit 1
fi

install_packages(){
    local PACKAGES=("$@")
    local INSTALL_REQUIRED=0
    for PACKAGE in "${PACKAGES[@]}"; do
        INSTALLED_VERSION=$(dpkg-query -W -f='${Version}' "$PACKAGE" 2>/dev/null || true)
        LATEST_VERSION=$(apt-cache policy "$PACKAGE" | grep Candidate | awk '{print $2}')
        
        if [ -z "$INSTALLED_VERSION" ] || [ "$INSTALLED_VERSION" != "$LATEST_VERSION" ]; then
            echo "$PACKAGE is not installed or not the latest version."
            INSTALL_REQUIRED=1
        fi
    done
    if [ $INSTALL_REQUIRED -eq 1 ]; then
        sudo -E apt update
        sudo -E apt install -y "${PACKAGES[@]}"
    fi
}

verify_dependencies_vpp(){
    echo -e "# Verifying VPP dependencies"
    DEPENDENCIES_PACKAGES=(
        build-essential
        pkg-config
        libudev-dev
        yasm
        autoconf
        libtool
        make
        meson
        python3
        numactl
        python3-pip
        zlib1g-dev
        libnuma-dev
        libssl-dev
        libboost-all-dev
        hwloc
        unzip
        nasm
        git
    )
    install_packages "${DEPENDENCIES_PACKAGES[@]}"
    echo "$S_VALID Dependencies installed";
}
#verify vpp
verify_vpp() {
    cd ~
    git clone https://gerrit.fd.io/r/vpp
    cd vpp
    git checkout v24.06-rc0
    make install-dep && make build-release && make install-ext-deps
    if ! make install-dep || ! make build-release || ! make install-ext-deps; then
        echo "Error: Failed to build VPP"
        exit 1
    fi
    cd ~/vpp/build/external/downloads/
    tar -xf dpdk-23.11.tar.xz

    cd ~/
    ./vpp/build-root/install-vpp-native/vpp/bin/vpp
    if ! ./vpp/build-root/install-vpp-native/vpp/bin/vpp; then
        echo "VPP Build Success in ~/vpp/build-root/install-vpp-native/vpp/bin/vpp"
    fi
}

setup() {
    verify_dependencies_vpp
    verify_vpp

    echo -e "\n# Status"
    echo "$S_VALID VPP configured"
}

setup

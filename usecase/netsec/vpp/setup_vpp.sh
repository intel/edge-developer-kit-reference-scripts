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
        python3-pyelftools
        zlib1g-dev
        libnuma-dev
        libssl-dev
        libboost-all-dev
        hwloc
        unzip
        git
    )
    install_packages "${DEPENDENCIES_PACKAGES[@]}"
    echo "$S_VALID Dependencies installed";
}
#verify vpp
verify_vpp() {
    cd /root/
    wget https://packagecloud.io/install/repositories/fdio/release/script.deb.sh --no-check-certificate
    chmod +x script.deb.sh
    ./script.deb.sh
    apt install libvppinfra=24.02-release -y
    apt install vpp=24.02-release -y
    apt install vpp-plugin-dpdk=24.02-release -y
    apt install vpp-plugin-core=24.02-release -y
    cd -
}

#verify nasm
verify_nasm() {
    cd /root/
    wget https://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.gz --no-check-certificate
    tar xvf nasm-2.14.02.tar.gz
    cd nasm-2.14.02
    ./configure
    make
    make install
    cd -
}

verify_intel_ipsec_mb() {
    cd /root
    git clone https://github.com/01org/intel-ipsec-mb -b v1.5
    cd intel-ipsec-mb
    make
    make install
    cd -
}

verify_dpdk() {
    cd /root
    git clone https://dpdk.org/git/dpdk -b v23.11
    cd dpdk
    #git clone git://dpdk.org/dpdk-stable -b v23.11
    #cd dpdk-stable
    CC=gcc meson -Dlibdir=lib -Dexamples=l3fwd,ipsec-secgw -Dc_args=-DRTE_LIBRTE_ICE_16BYTE_RX_DESC,-DCONFIG_RTE_LIBRTE_PMD_QAT_SYM --default-library=static build
    ninja -C build
    cd -
}

verify_trex() {
    cd /opt
    git clone https://github.com/cisco-system-traffic-generator/trex-core -b v3.04
    cd trex-core/linux_dpdk
    cp /lib/x86_64-linux-gnu/libstdc++.so.6 ../scripts/so/x86_64/.
    ./b configure --no-mlx=NO_MLX 
    ./b
    cd -
}
copy_config_files() {
    cp ./trex/trex_cfg.yaml /etc
    cp ./trex/*.py /opt/trex-core/scripts/stl/
    cp ./vpp/* /root
}

setup() {
    verify_dependencies_vpp
    verify_vpp
    verify_nasm
    verify_intel_ipsec_mb
    verify_dpdk
    verify_trex
    copy_config_files

    echo -e "\n# Status"
    echo "$S_VALID VPP configured"
}

setup

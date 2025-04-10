#! /bin/bash
#################################################################################
# This script will generate the Ubuntu Desktop Custom DiskImage from ISO provided
# supported from ubuntu-desktop 23.10 and above
# usage : generate-ubuntu-img-from-iso.sh <imgname> <iso_file_abs_path> <memory> <smp> 
# Parameters are optional 
# Default values  
# vmname = ubuntu-24.04-custom
# iso_file_abs_path = ./ubuntu-24.04-custom.iso
# memory=4096
# smp = 4
#
# Author: rgeddyse
# Date: 02-May-2024
################################################################################

# comment below line to reduce the verbose logs
set -Eex

if [ "$1" = "" ]; then
    VM_NAME="ubuntu_24.04_lts_desktop_custom"
else
    VM_NAME=$1
fi

if [ "$2" = "" ]; then
    OS_IMG=./ubuntu_24.04_lts_desktop_custom.iso
else
    OS_IMG=$2
fi

if [ "$3" = "" ]; then
    MEMORY=4096
else
    MEMORY=$3
fi

if [ "$4" = "" ]; then
    SMP=4
else
    SMP=$4
fi
echo "#################################################################"
if test -f "$VM_NAME.img"
then
    echo "Deleting the existing img image if any"	
    rm -rf "$VM_NAME".img
    sudo qemu-img create -f raw "$VM_NAME".img 30G
else
    echo "Generating raw img image"	
    sudo qemu-img create -f raw "$VM_NAME".img 30G
fi

if test -f OVMF.fd
then
    echo "OVMF file is already present"
    echo "Generating Disk .img image"
    sudo qemu-system-x86_64 \
        -enable-kvm \
        -smp "$SMP" \
        -m "$MEMORY" \
        -name "$VM_NAME".vm \
        -vnc :99 \
        -cpu host \
        -drive if=virtio,format=raw,file=./"$VM_NAME".img,cache=none \
        -drive file=./OVMF.fd,format=raw,if=pflash -drive file="$OS_IMG",media=cdrom \
        -device e1000,netdev=net0,mac=DE:AD:BE:EF:B1:11 \
        -netdev user,id=net0,ipv6=off,hostfwd=tcp::4444-:22 \
        -monitor tcp:127.0.0.1:55555,server,nowait 
else
    echo "Copying OVMF from host"
    cp /usr/share/ovmf/OVMF.fd .
    echo "Generating Disk .img Image"
    sudo qemu-system-x86_64 \
        -enable-kvm \
        -smp "$SMP" \
        -m "$MEMORY" \
        -name "$VM_NAME".vm \
        -vnc :99 \
        -cpu host \
        -drive if=virtio,format=raw,file=./"$VM_NAME".img,cache=none \
        -drive file=./OVMF.fd,format=raw,if=pflash -drive file="$OS_IMG",media=cdrom \
        -device e1000,netdev=net0,mac=DE:AD:BE:EF:B1:11 \
        -netdev user,id=net0,ipv6=off,hostfwd=tcp::4444-:22 \
        -monitor tcp:127.0.0.1:55555,server,nowait 

fi

#########################################################################
echo "####### Bmapfile creation for bmap flashing #######################"
if test -f "$VM_NAME".img
then
    echo "Creating bmapfile for flashing with bmaptool"
    sudo bmaptool create -o "$VM_NAME".img.bmap "$VM_NAME".img    
else
    echo "ERROR: There is an issue in previous step to generate $VM_NAME.img"
fi
#########################################################################


#########################################################################
echo "############ BZ2 file compression to upload #######################"
if test -f "$VM_NAME".img
then
    echo "Creating BZ2 compressed IMG image"
    sudo pbzip2 --compress --keep "$VM_NAME".img
    if test -f "$VM_NAME".img.bz2
    then
        echo "SUCCESS: compressed img.bz2 created successfully"
    fi
fi

#########################################################################
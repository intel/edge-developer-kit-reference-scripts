#!/bin/bash

# Copyright (C) 202\43 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

cd linux-kernel-overlay || { echo "linux-kernel-overlay folder not found"; exit 1; }

sudo dpkg -i linux-headers-6.1.80--000_6.1.80-0_amd64.deb
sudo dpkg -i linux-image-6.1.80--000_6.1.80-0_amd64.deb
sudo dpkg -i linux-libc-dev_6.1.80-0_amd64.deb

sudo update-grub
sudo reboot

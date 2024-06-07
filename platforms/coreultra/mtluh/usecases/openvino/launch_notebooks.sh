#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

CURRENT_DIRECTORY=$(pwd)
echo "${CURRENT_DIRECTORY}"

if docker ps | grep notebooks; then
    echo -e "# Remove existing notebook container"
    docker stop notebooks
    sleep 5 # For removal in progress
    if docker ps -a | grep notebooks; then
        docker rm notebooks
    fi
fi

docker run -t -u root -d --rm --name notebooks --net=host -v /etc/group:/etc/group --device=/dev/dri --device=/dev/accel --group-add="$(stat -c "%g" /dev/dri/render* | head -n 1)" -v "${CURRENT_DIRECTORY}":/mnt -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY="$DISPLAY" -p 8888:8888 \
openvino_notebook/ubuntu22_dev:latest

docker exec notebooks bash -c "cd /mnt/openvino_notebooks/notebooks ; jupyter-lab --allow-root --ip=0.0.0.0 --no-browser --NotebookApp.iopub_data_rate_limit=10000000"
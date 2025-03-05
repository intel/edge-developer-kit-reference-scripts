#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# Array of model sizes to process
models=("yolov8n" "yolov8s" "yolo11n" )

# Loop through each model size
for model in "${models[@]}"; do
    # Create folders for each precision
    mkdir -p "./${model}/FP32/" "./${model}/FP16/" "./${model}/INT8/"
    
    # Export models in different precisions and move to respective directories
    yolo export model="${model}.pt" format=openvino half=false imgsz=640,640
    mv "${model}_openvino_model/${model}."* "./${model}/FP32/"
    rm -rf "${model}_openvino_model"

    yolo export model="${model}.pt" format=openvino half=true imgsz=640,640
    mv "${model}_openvino_model/${model}."* "./${model}/FP16/"
    rm -rf "${model}_openvino_model"

    yolo export model="${model}.pt" format=openvino int8=true imgsz=640,640
    mv "${model}_int8_openvino_model/${model}."* "./${model}/INT8/"
    rm -rf "${model}_int8_openvino_model/" ./datasets
    rm -f "${model}.pt"

done

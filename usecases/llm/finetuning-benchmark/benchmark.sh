#!/bin/bash
# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

WORKDIR=$PWD
NUM_GPUS=1
NUM_CPU=$(lscpu | grep "^CPU(s):" | awk '{print $2}')

count_gpu_devices() {
    local search_patterns=(
        "Intel(R) Level-Zero, Intel(R) Arc(TM) A770 Graphics 1.3"
        "Intel(R) Level-Zero, Intel(R) Arc(TM) A770M Graphics 1.3"
        "Intel(R) Level-Zero, Intel(R) Data Center GPU Flex 170 1.3"
    )
    local count=0
    # Loop through each line of sycl-ls command output
    while IFS= read -r line; do
        for pattern in "${search_patterns[@]}"; do
            if [[ "$line" == *"$pattern"* ]]; then
                ((count++))
                break  # Exit the inner loop if a match is found
            fi
        done
    done < <(sycl-ls)
    # Return the count
    echo "$count"
}

validate_log_dir(){
    if [ ! -d "$WORKDIR"/logs ]; then
        echo -e "Creating logs dir"
        mkdir -p "$WORKDIR"/logs
    fi
}

validate_hf_token(){
    if [ ! -f ~/.cache/huggingface/token ]; then
        echo -e "Input your huggingface token. Please make sure you have the access to download and use the model."
        read -rsp 'Hugging Face token: ' HUGGINGFACE_TOKEN
        huggingface-cli login --token "$HUGGINGFACE_TOKEN" --add-to-git-credential
    else
        echo -e "Hugging Face token is already available. Skipping login. If you want to use a new token, please use huggingface-cli logout to clear your current token"
    fi
}

validate_num_gpu(){
    if [ -z "$1" ]; then
        echo -e "Number of GPUs is not provided. Default to use all available GPUs"
        NUM_GPUS=$(count_gpu_devices)
    else
        NUM_GPUS=$1
    fi
    echo -e "Using number of GPUs: $NUM_GPUS"
}

main(){
    echo -e "Exporting OneAPI environment"
    # shellcheck source=/dev/null
    source /opt/intel/oneapi/setvars.sh --force
    
    validate_log_dir
    validate_hf_token
    validate_num_gpu "$1"

    echo -e "Exporting environment"
    export CCL_LOG_LEVEL=error
    export OMP_NUM_THREADS=$NUM_CPU
    export MASTER_ADDR=127.0.0.1
    export FI_PROVIDER=tcp
    export CCL_ATL_TRANSPORT=ofi

    echo -e "Exporting env that is optimized for ARC"
    export USE_XETLA=OFF
    export SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1
    export SYCL_CACHE_PERSISTENT=1

    echo -e "Starting training with $NUM_CPU CPU cores and $NUM_GPUS GPU"
    echo -e "You can check the token efficiency in the log file in $WORKDIR/logs/training.log."
    mpirun -n "$NUM_GPUS" \
        python3 -u ./finetuning.py > "$WORKDIR"/logs/training.log
}

main "$1"
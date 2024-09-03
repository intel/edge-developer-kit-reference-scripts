#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0 

set -e

# BKC
ONEAPI_VERSION="2024.1"

OLLAMA_DIR="./ollama_dir"
ENV_DIR="./llm_env"

# verify current user
if [ "$EUID" -eq 0 ]; then
    echo "Must not run with sudo or root user"
    exit 1
fi


start(){
    trap cleanup SIGINT

    echo -e "\n# Preparing to start application..."

    # shellcheck source=/dev/null
    source $ENV_DIR/bin/activate
    
    cd "$OLLAMA_DIR"
    export OLLAMA_NUM_GPU=999
    export no_proxy=localhost,127.0.0.1
    export ZES_ENABLE_SYSMAN=1

    # shellcheck source=/dev/null
    source /opt/intel/oneapi/$ONEAPI_VERSION/oneapi-vars.sh --force
    export SYCL_CACHE_PERSISTENT=1
    
    ./ollama serve &
    P1=$!
    open-webui serve --host 127.0.0.1 &
    P2=$!

    while ! service_is_ready; do
        :
    done
    xdg-open "http://localhost:8080/"
    wait $P1 $P2
}

service_is_ready(){
    curl -s -o /dev/null http://localhost:8080 && curl -s -o /dev/null http://localhost:11434
}

cleanup(){
    kill $P1 $P2
    wait $P1 $P2
    exit 1
}


setup() {

    start
}

setup
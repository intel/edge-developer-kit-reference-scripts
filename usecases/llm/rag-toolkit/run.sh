#!/bin/bash
# INTEL CONFIDENTIAL
# Copyright (C) 2024, Intel Corporation

WORKDIR=$PWD
# S_VALID="✓"
S_INVALID="✗"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
SERVING_LOGFILE="$TIMESTAMP/serving.log"
BACKEND_LOGFILE="$TIMESTAMP/backend.log"
UI_LOGFILE="$TIMESTAMP/ui.log"

DEVICE=""
SERVING_PORT=8012
MODEL_DIR=$WORKDIR/data/model

if [ "$EUID" -eq 0 ]; then
    echo "$S_INVALID Must not run with sudo or root user"
    exit 1
fi

read_choice(){
    echo -e "- Verifying if device choice is available"
    if [[ -f "$WORKDIR"/.device ]]
    then
        DEVICE=$(cat .device)
    else
        echo "$S_INVALID Cannot get the device choice. Please run the setup.sh script first."
        exit 1
    fi
}

prepare_env(){
    if [ ! -d "$WORKDIR/logs/$TIMESTAMP" ]; then
        mkdir -p "$WORKDIR/logs/$TIMESTAMP"
    fi
}

verify_ov_model_exist(){
    echo -e "Verifying if OV model is available"
    if [ ! -d "$MODEL_DIR/ov_llm" ]; then
        echo -e "OV model not found in $MODEL_DIR/ov_llm. Please run the setup.sh script first."
        exit 1
    fi
}

verify_gguf_model_exist(){
    echo -e "Verifying if GGUF model is available"
    if [ ! -d "$MODEL_DIR/gguf" ]; then
        echo -e "GGUF model not found in $MODEL_DIR/gguf. Please run the setup.sh script first."
        exit 1
    fi
}

activate_virtual_env(){
    echo -e "Verifying if python3 virtual env is available"
    if [ ! -d "$WORKDIR/.venv" ]; then
        echo -e "OV model not found in $WORKDIR/.venv. Please run the setup.sh script first to setup the environment"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$WORKDIR"/.venv/bin/activate
}

vllm_openvino_serving(){
    if [ -f "$WORKDIR/data/serving.pid" ]; then
        echo -e "Serving service is already running."
        return
    fi

    verify_ov_model_exist
    activate_virtual_env

    echo -e "Starting model serving using device: CPU"
    VLLM_OPENVINO_KVCACHE_SPACE=8 VLLM_OPENVINO_CPU_KV_CACHE_PRECISION=u8 VLLM_OPENVINO_ENABLE_QUANTIZED_WEIGHTS=ON \
        python3 -m vllm.entrypoints.openai.api_server \
            --host 0.0.0.0 \
            --port "$SERVING_PORT" \
            --model "$MODEL_DIR" \
            --device openvino > "$WORKDIR/logs/$SERVING_LOGFILE"
}

llamacpp_serving(){
    if [ -f "$WORKDIR/data/serving.pid" ]; then
        echo -e "Serving service is already running."
        return
    fi

    echo -e "Starting serving services"
    verify_gguf_model_exist
    activate_virtual_env
    echo -e "Activating OneAPI environment"
    # shellcheck source=/dev/null
    source /opt/intel/oneapi/setvars.sh --force

    echo -e "Starting model serving using device: GPU"
    ZES_ENABLE_SYSMAN=1 python3 -m llama_cpp.server \
        --host 0.0.0.0 \
        --port "$SERVING_PORT" \
        --model ./data/model/gguf/model.gguf \
        --n_ctx 4096 \
        --n_gpu_layers -1 \
        --split_mode 0 \
        --main_gpu 0 > "$WORKDIR/logs/$SERVING_LOGFILE"
}

start_serving(){
    if [ "$DEVICE" == "CPU" ]; then
        vllm_openvino_serving
    elif [ "$DEVICE" == "GPU" ]; then
        llamacpp_serving
    else
        echo "$S_INVALID Device: $DEVICE is not supported. Please uninstall and install again"
        exit 1
    fi
}

start_backend(){
    echo -e "Starting backend services"
    activate_virtual_env
    cd "$WORKDIR"/backend || exit
    python3 app.py > "$WORKDIR/logs/$BACKEND_LOGFILE"
}

start_ui(){
    echo -e "Starting ui services"
    cd "$WORKDIR"/edge-ui || exit
    npm run dev > "$WORKDIR/logs/$UI_LOGFILE"
}

stop_services() {
    echo -e "\n Stopping all running services ..."
    kill "$P_SERVING" "$P_BACKEND" "$P_UI"
    wait "$P_SERVING" "$P_BACKEND" "$P_UI"
    exit 1
}

main(){
    echo -e "######################"
    echo -e "# Intel® LLM On Edge #"
    echo -e "######################"
    echo -e ""
    trap stop_services SIGINT

    read_choice
    prepare_env

    start_serving &
    P_SERVING=$!

    start_backend &
    P_BACKEND=$!

    start_ui &
    P_UI=$!

    wait "$P_SERVING" "$P_BACKEND" "$P_UI"
}

main
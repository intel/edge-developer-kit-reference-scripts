#!/bin/bash
# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# Settings
BACKEND_HOST=127.0.0.1
BACKEND_PORT=8011
SERVING_HOST=127.0.0.1
SERVING_PORT=8012
OLLAMA_MODEL_ID="mistral"
QUANT_FORMAT="Q4_K_M"
OV_VLLM_MODEL_ID="mistralai/Mistral-7B-Instruct-v0.3"
OV_QUANT_FORMAT="int4"
OLLAMA_CUSTOM_MODEL_ID="intel-llm-model"

# Applications
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
SERVING_LOGFILE="$TIMESTAMP/serving.log"
BACKEND_LOGFILE="$TIMESTAMP/backend.log"
UI_LOGFILE="$TIMESTAMP/ui.log"
ONEAPI_VERSION="2024.0"
FRAMEWORK=""
RUNNING_OLLAMA_MODEL_ID=""

export OLLAMA_MODELS="./data/model/ollama/cache"

if [ "$EUID" -eq 0 ]; then
    print_info "Must not run with sudo or root user"
    exit 1
fi

# Common
print_info(){
    local info="$1"
    echo -e "\n# $info"
}

read_choice(){
    print_info "Verifying if framework choice is available"
    if [[ -f "./.framework" ]]
    then
        FRAMEWORK=$(cat ./.framework)
        echo -e "Framework: $FRAMEWORK"
    else
        echo "- Unable to get the framework choice. Please run the setup.sh script first."
        exit 1
    fi

    if [ "$FRAMEWORK" == "OV_VLLM" ]; then
        validate_hf_token
    fi
}

prepare_env(){
    if [ ! -d "./logs/$TIMESTAMP" ]; then
        mkdir -p "./logs/$TIMESTAMP"
    fi
}

# Utils
install_python_packages() {
    local packages=("$@")
    for PACKAGE_NAME in "${packages[@]}"; do
        if pip show "$PACKAGE_NAME" &> /dev/null; then
            echo "Package '$PACKAGE_NAME' is installed. Skipping installation"
        else
            echo "Package '$PACKAGE_NAME' is not installed. Installing ..."
            python3 -m pip install "$PACKAGE_NAME"
        fi
    done
}

activate_python_venv(){
    if ! command -v python3.11 &> /dev/null; then
        print_info "Installing Python 3.11"
        PYTHON_PACKAGES=(
            python3.11
            python3.11-venv
        )
        install_packages "${PYTHON_PACKAGES[@]}"
    fi

    [ ! -d "./.venv" ] && python3.11 -m venv ./.venv

    print_info "Activating Python 3.11 environment"
    # shellcheck source=/dev/null
    source "./.venv/bin/activate"
}

validate_hf_token(){
    activate_python_venv
    packages=(
        huggingface_hub
    )
    install_python_packages "${packages[@]}"
    export HF_HOME="./data/huggingface"
    if [ ! -f "./data/huggingface/token" ]; then
        if [ -z "$HF_TOKEN" ]; then
            echo -e "Input your Hugging Face token."
            read -rsp 'Hugging Face token: ' HF_TOKEN
            if [ -z "$HF_TOKEN" ]; then
                echo -e "\n- Please enter a valid Hugging Face token"
                exit 1
            fi
        fi
        huggingface-cli login --token "$HF_TOKEN"
    else
        echo -e "Hugging Face token is already available. Skipping login. If you want to use a new token, please remove your token in $WORKDIR/data/huggingface/token"
    fi
}

verify_ov_vllm_model(){
    local downloaded_model_dir="./data/model/llm"
    local model_dir="./data/model/ov"

    print_info "Verify OpenVINO LLM model available"
    if [ ! -d "$model_dir" ]; then
        if [ ! -d "$downloaded_model_dir" ]; then
            echo -e "- Downloading default model: $OV_VLLM_MODEL_ID for OpenVINO. Please ensure you have network access."
            if optimum-cli export openvino --model "$OV_VLLM_MODEL_ID" \
                --weight-format "$OV_QUANT_FORMAT" "$model_dir"
            then
                echo -e "- Successfully download OV model: $OV_VLLM_MODEL_ID"
            else
                echo -e "- Failed to download OV model: $OV_VLLM_MODEL_ID"
                exit 1
            fi
        else
            echo -e "- Converting model to OpenVINO format"
            if optimum-cli export openvino --task text-generation-with-past \
                --framework pt \
                --weight-format "$OV_QUANT_FORMAT" \
                --model "$downloaded_model_dir" "$model_dir"
            then
                echo -e "- Successfully convert OV model: $downloaded_model_dir"
            else
                echo -e "- Failed to convert OV model: $downloaded_model_dir"
                exit 1
            fi
        fi
    else
        echo -e "- OpenVINO model is available. Skipping downloading"
    fi
}

is_ollama_running(){
    curl -s -o /dev/null http://localhost:11434
}

verify_ollama_model(){
    local downloaded_model_dir="./data/model/llm"
    local ollama_modelfile="./data/model/gguf/Modelfile"

    activate_python_venv
    print_info "Verify Ollama model available"

    ./thirdparty/ollama_bin/ollama serve &
    P1=$!
    while ! is_ollama_running; do
        sleep 5
    done

    if [ ! -d "$downloaded_model_dir" ]; then
        RUNNING_OLLAMA_MODEL_ID=$OLLAMA_MODEL_ID
    else
        RUNNING_OLLAMA_MODEL_ID=$OLLAMA_CUSTOM_MODEL_ID
    fi

    output=$(./thirdparty/ollama_bin/ollama list 2>&1 | grep $RUNNING_OLLAMA_MODEL_ID)
    if [[ $output == "" ]]; then
        echo -e "- Ollama model: $RUNNING_OLLAMA_MODEL_ID not found. Preparing model ..."
        if [[ $RUNNING_OLLAMA_MODEL_ID == "$OLLAMA_MODEL_ID" ]]; then
            if ./thirdparty/ollama_bin/ollama pull "$OLLAMA_MODEL_ID"
            then
                echo -e "- Successfully download Ollama model: $OLLAMA_MODEL_ID"
                kill "$P1"
            else
                echo -e "- Failed to download Ollama model: $OLLAMA_MODEL_ID. Please ensure you have valid network connection."
                kill "$P1"
                exit 1
            fi
        elif [[ $RUNNING_OLLAMA_MODEL_ID == "$OLLAMA_CUSTOM_MODEL_ID" ]]; then
            if [ ! -f "$ollama_modelfile" ]; then
                echo -e "- Creating custom Ollama Modelfile"
                mkdir -p ./data/model/gguf
                python3 ./backend/scripts/convert_ollama.py --model_path ./data/model/llm --save_path "$ollama_modelfile"
            fi

            if ./thirdparty/ollama_bin/ollama create -f "$ollama_modelfile" --quantize "$QUANT_FORMAT" "$OLLAMA_CUSTOM_MODEL_ID"
            then
                echo -e "- Successfully to create Ollama model"
                kill "$P1"
            else
                echo -e "- Failed to create Ollama model"
                kill "$P1"
                exit 1
            fi
        fi
    else
        echo -e "- Ollama model: $RUNNING_OLLAMA_MODEL_ID is already available"
    fi
}

# Steps
start_ollama_backend(){
    print_info "Starting Ollama backend"
    export OLLAMA_HOST="$SERVING_HOST:$SERVING_PORT"
    export OLLAMA_KEEP_ALIVE=-1
    export OLLAMA_NUM_GPU=999
    export no_proxy=localhost,127.0.0.1
    export ZES_ENABLE_SYSMAN=1

    # shellcheck source=/dev/null
    source /opt/intel/oneapi/$ONEAPI_VERSION/oneapi-vars.sh --force
    export SYCL_CACHE_PERSISTENT=1
    export SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1

    ./thirdparty/ollama_bin/ollama serve > "./logs/$SERVING_LOGFILE"
}

preload_ollama_model(){
    local downloaded_model_dir="./data/model/llm"
    
    if [ ! -d "$downloaded_model_dir" ]; then
        RUNNING_OLLAMA_MODEL_ID=$OLLAMA_MODEL_ID
    else
        RUNNING_OLLAMA_MODEL_ID=$OLLAMA_CUSTOM_MODEL_ID
    fi

    print_info "Preloading Ollama model: $RUNNING_OLLAMA_MODEL_ID"
    if ! curl http://localhost:$SERVING_PORT/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d '{
            "model": "'"$RUNNING_OLLAMA_MODEL_ID"'",
            "messages": [
                {
                    "role": "user",
                    "content": "Reply yes"
                }
            ]
        }'
    then
        echo -e "Failed to preload Ollama model: $RUNNING_OLLAMA_MODEL_ID"
        exit 1
    fi
}

start_ov_vllm_backend(){
    local model_dir="./data/model/ov"
    print_info "Starting OV VLLM backend"
    if [ ! -f "$model_dir/openvino_model.xml" ]; then
        echo -e "- Unable to find the OpenVINO LLM model in $model_dir"
        exit 1
    fi

    activate_python_venv
    export VLLM_OPENVINO_KVCACHE_SPACE=8 
    export VLLM_OPENVINO_CPU_KV_CACHE_PRECISION=u8 
    export VLLM_OPENVINO_ENABLE_QUANTIZED_WEIGHTS=ON
    python3 -m vllm.entrypoints.openai.api_server \
        --host "$SERVING_HOST" \
        --port "$SERVING_PORT" \
        --model "$model_dir" \
        --device openvino > "./logs/$SERVING_LOGFILE"
}

start_serving(){
    if [ "$FRAMEWORK" == "OV_VLLM" ]; then
        verify_ov_vllm_model
        start_ov_vllm_backend
    elif [ "$FRAMEWORK" == "OLLAMA" ]; then
        verify_ollama_model
        start_ollama_backend
    else
        echo "- FRAMEWORK: $FRAMEWORK is not supported. Please uninstall and install again"
        exit 1
    fi
}

start_backend(){
    print_info "Starting backend services"
    activate_python_venv
    cd ./backend || exit
    uvicorn app:app --host "$BACKEND_HOST" --port "$BACKEND_PORT" > "../logs/$BACKEND_LOGFILE"
}

start_ui(){
    print_info "Starting ui services"
    cd ./edge-ui || exit
    export NEXT_TELEMETRY_DISABLED=1
    npm run start > "../logs/$UI_LOGFILE"
}

is_serving_running(){
    curl -s -o /dev/null "http://localhost:$SERVING_PORT"
}

validate_serving_running(){
    print_info "Verifying if serving service is ready"
    while ! is_serving_running; do
        sleep 5
    done
    preload_ollama_model
    echo -e "- Serving service is ready!"
}

is_backend_running(){
    if curl -s "http://localhost:$BACKEND_PORT/healthcheck" | grep -q 'OK'; then
        return 0 
    else
        return 1 
    fi
}

validate_backend_running(){
    print_info "Verifying if backend service is ready"
    while ! is_backend_running; do
        sleep 5
    done
    echo -e "- Backend service is ready!"
}

is_ui_running(){
    curl -s -o /dev/null "http://localhost:8010"
}

validate_ui_running(){
    print_info "Verifying if UI service is ready"
    while ! is_ui_running; do
        sleep 5
    done
    echo -e "- UI service is ready!"
}

stop_services() {
    print_info "Stopping all running services ..."
    kill "$P_SERVING" "$P_BACKEND" "$P_UI"
    wait "$P_SERVING" "$P_BACKEND" "$P_UI"
    exit 0
}

main(){
    echo -e "######################"
    echo -e "# Intel® LLM On Edge #"
    echo -e "######################"
    trap stop_services SIGINT

    read_choice
    prepare_env

    start_serving &
    P_SERVING=$!
    validate_serving_running

    start_backend &
    P_BACKEND=$!
    validate_backend_running

    start_ui &
    P_UI=$!
    validate_ui_running

    print_info "Application started successfully"
    echo -e "- Application is running on http://localhost:8010"

    wait "$P_SERVING" "$P_BACKEND" "$P_UI"
}

main
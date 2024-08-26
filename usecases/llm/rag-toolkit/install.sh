#!/bin/bash
# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

WORKDIR=$PWD
S_VALID="✓"

# Settings 
ONEAPI_VER="2024.2"
DEFAULT_MODEL_ID=mistralai/Mistral-7B-Instruct-v0.3

# App version
VLLM_COMMIT=80cbe10
LLAMACPP_COMMIT="b3538"
LLAMACPP_PYTHON_VER="0.2.87"
MODEL_DIR=$WORKDIR/data/model/llm

if [ "$EUID" -eq 0 ]; then
    echo "Must not run with sudo or root user"
    exit 1
fi

create_python_venv(){
    echo -e "Installing python3-venv dependencies"
    sudo apt install -y python3-venv

    if [ -d "$WORKDIR/.venv" ]; then
        echo -e "Virtual environment already exists in $WORKDIR/.venv. Skipping creation"
    else
        echo -e "Creating virtual environment in $WORKDIR/.venv"
        python3 -m venv "$WORKDIR"/.venv
    fi
}

activate_python_venv(){
    echo -e "Activating python venv"
    if [ -d "$WORKDIR/.venv" ]; then
        # shellcheck source=/dev/null
        source "$WORKDIR"/.venv/bin/activate
    else
        echo -e "Unable to find python venv in $WORKDIR/.venv."
    fi
}

validate_python_packages() {
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

validate_hf_token(){
    packages=(
        huggingface_hub
    )
    validate_python_packages "${packages[@]}"
    export HF_HOME="$WORKDIR/data/huggingface"
    if [ ! -f "$WORKDIR/data/huggingface/token" ]; then
        echo -e "Input your huggingface token. Please make sure you have the access to download $DEFAULT_MODEL_ID model. Link: https://huggingface.co/$DEFAULT_MODEL_ID"
        read -rsp 'Hugging Face token: ' HUGGINGFACE_TOKEN
        huggingface-cli login --token "$HUGGINGFACE_TOKEN"
    else
        echo -e "Hugging Face token is already available. Skipping login. If you want to use a new token, please remove your token in $WORKDIR/data/huggingface/token"
    fi
}

download_default_model(){
    echo -e "Downloading model: $DEFAULT_MODEL_ID to $WORKDIR/data/model/llm"
    huggingface-cli download "$DEFAULT_MODEL_ID" --local-dir "$WORKDIR"/data/model/llm

    if [ ! -d "$WORKDIR/data/model/llm" ]; then
        echo -e "Failed to download model from Hugging Face"
        exit 1
    fi
}

validate_model_available(){
    echo -e "Verifying if model available"
    if [ ! -d "$MODEL_DIR" ]; then
        echo -e "Unable to find trained model in $MODEL_DIR."
        activate_python_venv
        validate_hf_token
        download_default_model
    else
        echo -e "Trained model available."
    fi
}

validate_oneapi_available(){
    echo -e "Verifying if Intel OneAPI basekit available"
    if [ ! -f "/opt/intel/oneapi/setvars.sh" ]; then
        echo -e "Intel OneAPI basekit not found. Installing ..."
        setup_oneapi
    else
        echo -e "Intel OneAPI basekit is already installed. Skipping installation"
    fi
}

setup_dependencies(){
    sudo apt update
    sudo apt install -y build-essential wget git cmake

    echo -e "Installing GPU drivers"
    wget -O /tmp/setup.sh https://raw.githubusercontent.com/intel/edge-developer-kit-reference-scripts/main/gpu/arc/dg2/setup.sh
    chmod +x /tmp/setup.sh
    /tmp/setup.sh
}

setup_oneapi(){
    sudo apt update
    sudo apt install -y gpg-agent wget
    
    wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list

    sudo apt update
    sudo apt install -y intel-basekit-"$ONEAPI_VER"
}

setup_llamacpp_sycl(){
    echo -e "Activating OneAPI environment"
    # shellcheck source=/dev/null
    source /opt/intel/oneapi/setvars.sh --force

    echo -e "Activating virtual environment"
    # shellcheck source=/dev/null
    source "$WORKDIR"/.venv/bin/activate

    echo -e "Installing llama.cpp python, version: $LLAMACPP_PYTHON_VER"
    CMAKE_ARGS="-DGGML_SYCL=ON -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icpx" FORCE_CMAKE=1 python3 -m pip install --upgrade --force-reinstall --no-cache-dir "llama-cpp-python[server]==$LLAMACPP_PYTHON_VER"

    mkdir -p "$WORKDIR"/thirdparty
    cd "$WORKDIR"/thirdparty || exit
    if [ -d "$WORKDIR/thirdparty/llama.cpp" ]; then
        echo -e "llama.cpp repository is already available."
    else
        echo -e "Cloning llama.cpp, branch: $LLAMACPP_COMMIT"
        git clone https://github.com/ggerganov/llama.cpp.git llama.cpp && cd llama.cpp && git checkout $LLAMACPP_COMMIT
    fi

    if [ ! -d "$WORKDIR/thirdparty/llama.cpp/build" ]; then
        cd "$WORKDIR"/thirdparty/llama.cpp || exit
        cmake -B build -DGGML_SYCL=ON -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icpx
        cmake --build build --config Release -j -v
    fi
}

setup_vllm_openvino(){
    echo -e "Installing git dependencies"
    sudo apt install -y git

    mkdir -p "$WORKDIR"/thirdparty
    cd "$WORKDIR"/thirdparty || exit
    if [ -d "$WORKDIR/thirdparty/vllm" ]; then
        echo -e "VLLM repository is already available."
    else
        echo -e "Cloning VLLM, branch: $VLLM_COMMIT"
        git clone https://github.com/vllm-project/vllm.git vllm && cd vllm && git checkout "$VLLM_COMMIT"
    fi

    echo -e "Activating virtual environment"
    # shellcheck source=/dev/null
    source "$WORKDIR"/.venv/bin/activate

    echo -e "Upgrading pip version"
    python3 -m pip install --upgrade pip

    echo -e "Installing VLLM with OpenVINO backend"
    cd "$WORKDIR"/thirdparty/vllm || exit
    python3 -m pip install -r requirements-build.txt --extra-index-url https://download.pytorch.org/whl/cpu
    PIP_PRE=1 PIP_EXTRA_INDEX_URL="https://download.pytorch.org/whl/cpu https://storage.openvinotoolkit.org/simple/wheels/nightly/" VLLM_TARGET_DEVICE=openvino python -m pip install -v .
}

setup_vllm_xpu(){
    echo -e "Installing git dependencies"
    sudo apt install -y git

    mkdir -p "$WORKDIR"/thirdparty
    cd "$WORKDIR"/thirdparty || exit
    if [ -d "$WORKDIR/thirdparty/vllm-xpu" ]; then
        echo -e "VLLM repository is already available."
    else
        echo -e "Cloning VLLM, branch: main"
        git clone https://github.com/vllm-project/vllm.git vllm-xpu
    fi

    echo -e "Activating virtual environment"
    # shellcheck source=/dev/null
    source "$WORKDIR"/.venv/bin/activate

    echo -e "Upgrading pip version"
    python3 -m pip install --upgrade pip

    echo -e "Installing VLLM with XPU backend"
    cd "$WORKDIR"/thirdparty/vllm-xpu || exit
    # shellcheck source=/dev/null
    source /opt/intel/oneapi/setvars.sh --force
    python3 -m pip install -v -r requirements-xpu.txt
    VLLM_TARGET_DEVICE=xpu python setup.py install
}

convert_model_to_ov_format(){
    TASK=text-generation-with-past
    WEIGHT_FORMAT=int4
    FRAMEWORK=pt

    echo -e "Verifying if model weight file is available"
    if [ ! -d "$MODEL_DIR" ]; then
        echo -e "Model file is not available. Unable to convert model to OpenVINO format"
        exit 1
    fi

    if [ -d "$EXPORT_DIR" ]; then
        echo -e "Model has been converted before. Please check $EXPORT_DIR"
        exit 0
    fi

    echo -e "Activating virtual environment"
    # shellcheck source=/dev/null
    source "$WORKDIR"/.venv/bin/activate

    echo -e "Converting model to OpenVINO IR format"
    optimum-cli export openvino --task "$TASK" --model "$MODEL_DIR" --weight-format "$WEIGHT_FORMAT" --framework "$FRAMEWORK" "$WORKDIR"/data/model/ov_llm

    if [ ! -d "$MODEL_DIR" ]; then
        echo -e "Model conversion failed."
        exit 1
    else
        echo -e "Model converted to OpenVINO IR successfully."
    fi
}

convert_model_to_gguf_format(){
    echo -e "\n# Setting up model for GGUF format"
    # shellcheck source=/dev/null
    source "$WORKDIR"/.venv/bin/activate

    cd "$WORKDIR"/thirdparty/llama.cpp || exit
    python3 -m pip install -r requirements.txt

    if [ ! -f "$WORKDIR/data/model/gguf/model.gguf" ]; then
        echo -e "- Converting model to GGUF format"
        mkdir -p "$WORKDIR"/data/model/gguf
        python3 convert_hf_to_gguf.py "$WORKDIR"/data/model/llm --outfile "$WORKDIR"/data/model/gguf/model.gguf
    else
        echo -e "- Model found in $WORKDIR/data/model/gguf/model.gguf. Skipping conversion."
    fi

    if [ ! -f "$WORKDIR/data/model/gguf/model-Q4_K_M.gguf" ]; then
        echo -e "- Quantize gguf model to Q4_K_M"
        mkdir -p "$WORKDIR"/data/model/gguf
        "$WORKDIR"/thirdparty/llama.cpp/build/bin/llama-quantize "$WORKDIR"/data/model/gguf/model.gguf "$WORKDIR"/data/model/gguf/model-Q4_K_M.gguf Q4_K_M
    else
        echo -e "- Model is already quantize to Q4_K_M format. Skipping quantization."
    fi
}

setup_tts(){
    echo -e "\n# Installing TTS environment"
    sudo apt-get install -y build-essential libsndfile1 git

    # shellcheck source=/dev/null
    source "$WORKDIR"/.venv/bin/activate
    cd "$WORKDIR"/thirdparty || exit
    if [ -d "$WORKDIR/thirdparty/MeloTTS" ]; then
        echo -e "- MeloTTS repository is already available."
    else
        echo -e "- Cloning MeloTTS, branch: main"
        git clone https://github.com/myshell-ai/MeloTTS.git MeloTTS
    fi

    cd "$WORKDIR"/thirdparty/MeloTTS || exit
    python3 -m pip install -e .
    python3 -m unidic download
}

write_choice(){
    echo "$1" > "$WORKDIR"/.device
}

setup_backend(){
    echo -e "\n# Setting up backend services"
    # shellcheck source=/dev/null
    source "$WORKDIR"/.venv/bin/activate

    if [ ! -d "./data/model/embeddings/bge-large-en-v1.5" ]; then
        echo -e "- Getting embedding model: bge-large-en-v1.5"
        optimum-cli export openvino --model BAAI/bge-large-en-v1.5 --task feature-extraction ./data/model/embeddings/bge-large-en-v1.5
    fi

    if [ ! -d "./data/model/reranker/bge-reranker-large" ]; then
        echo -e "- Getting embedding model: bge-reranker-large"
        optimum-cli export openvino --model BAAI/bge-reranker-large --task text-classification ./data/model/reranker/bge-reranker-large
    fi

    echo -e "- Installing backend dependencies"
    cd "$WORKDIR"/backend || exit
    python3 -m pip install --no-deps openai-whisper 
    python3 -m pip install -r requirements.txt
}

setup_ui(){
    echo -e "\n# Setting up UI services"
    echo -e "- Verifying if nodejs is available"
    if command -v node &> /dev/null
    then
        NODE_VERSION=$(node -v)
        if [[ "$NODE_VERSION" == v22* ]]
        then
            echo "- Node.js version 22 is installed."
        else
            echo "- Node.js is installed, but the version is not 22. Installed version: $NODE_VERSION"
        fi
    else
        echo -e "- Installing Node.js version 22"
        sudo apt update
        sudo apt install -y curl

        curl -fsSL https://deb.nodesource.com/setup_22.x -o /tmp/nodesource_setup.sh
        sudo bash /tmp/nodesource_setup.sh
        sudo apt install -y nodejs
        rm -rf /tmp/nodesource_setup.sh
    fi

    echo -e "- Setting up UI in $WORKDIR/edge-ui"
    cd "$WORKDIR"/edge-ui || exit
    npm install
}

entrypoint(){
    echo -e "############################"
    echo -e "# LLM On Edge Installation #"
    echo -e "############################"
    echo -e ""
    echo -e "Select the device you would like to run on:"
    echo -e "1) CPU"
    echo -e "2) GPU"
    read -rp "Enter your choice [1 or 2]: " choice
    case $choice in
    1)
        setup_dependencies
        create_python_venv
        validate_model_available
        setup_vllm_openvino
        convert_model_to_ov_format
        write_choice "CPU"
        ;;
    2)
        setup_dependencies
        create_python_venv
        validate_model_available
        validate_oneapi_available
        setup_llamacpp_sycl
        convert_model_to_gguf_format
        write_choice "GPU"
        ;;
    *)
        echo "Invalid choice. Please enter 1 or 2."
        exit 1
        ;;
    esac
    setup_tts
    setup_backend
    setup_ui
    echo -e "$S_VALID Successfully setup the application. Please execute the run script to start the application"
}

entrypoint
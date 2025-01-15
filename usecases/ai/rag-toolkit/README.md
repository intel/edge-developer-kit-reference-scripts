# LLM Deployment Toolkit
The Deployment Toolkit is a sophisticated Language Model (LLM) application designed to leverage the power of Intel CPUs and GPUs. It features Retrieval Augmented Generation (RAG), a cutting-edge technology that enhances the model's ability to generate accurate and contextually relevant responses by integrating external information retrieval mechanisms.

![LLM Deployment Toolkit](./assets/ui.gif)

## Requirements
### Validated hardware
* CPU: 13th generations of Intel Core processors and above
* GPU: Intel® Arc™ graphics
* RAM: 32GB
* DISK: 128GB

### Validated software version
* OpenVINO: 2024.6.0
* NodeJS: v22.13.0 LTS

### Application ports
Please ensure that you have these ports available before running the applications.
| Apps                   | Port |
|------------------------|------|
| UI                     | 8010 |
| Backend                | 8011 |
| LLM Service            | 8012 |
| Text to Speech Service | 8013 |
| Speech to Text Service | 8014 |

## Quick Start
<details open><summary>Ubuntu 22.04 LTS</summary>

### 1. Install prerequisite
- [Docker](https://docs.docker.com/engine/install/)

### 2. Install GPU driver
- [Intel® Arc™ A-Series Graphics](https://github.com/intel/edge-developer-kit-reference-scripts/tree/main/gpu/arc/dg2)
- [Intel® Data Center GPU Flex Series](https://github.com/intel/edge-developer-kit-reference-scripts/tree/main/gpu/flex/ats)

### 3. Download LLM model (Skip if you already have a LLM model in data folder)
```bash
# Install OpenVINO library
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install openvino==2024.6 optimum-intel[openvino,nncf]==1.21.0 --extra-index-url https://download.pytorch.org/whl/cpu

# Download & Convert LLM Model
optimum-cli export openvino --model Qwen/Qwen2.5-7B-Instruct --weight-format int4 --sym --ratio 1.0 --group-size -1 ./data/models/llm
```

### 4. Download embedding model and reranker model
```bash
# Download & Convert Embedding Model
optimum-cli export openvino --model BAAI/bge-large-en-v1.5 --task feature-extraction --weight-format fp16 ./data/models/embeddings/bge-large-en-v1.5

# Download & Convert Reranker Model
optimum-cli export openvino --model BAAI/bge-reranker-large --task text-classification --weight-format fp16 ./data/models/reranker/bge-reranker-large
```

### 5. Build docker images
This step will download all the necessary files online, please ensure you have a valid network connection.
```bash
docker compose build
```

### 6. Start docker container
```bash
export RENDER_GROUP_ID=$(getent group render | cut -d: -f3)
docker compose up -d
```
</details>

<details><summary>Windows 11</summary>

### 1. Install prerequisite
- [Python 3.11.9 (64-bit)](https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe)
- [Intel® oneAPI Base Toolkit version 2024.2.1](https://www.intel.com/content/www/us/en/developer/tools/oneapi/base-toolkit-download.html)
- [Node.js v22.12.0](https://nodejs.org/en/download/package-manager)

### 2. Install GPU driver
- [Intel® Arc™ & Iris® Xe Graphics - Windows](https://www.intel.com/content/www/us/en/download/785597/intel-arc-iris-xe-graphics-windows.html) 
- [Intel® Data Center GPU Flex Series - Windows](https://www.intel.com/content/www/us/en/download/780185/intel-data-center-gpu-flex-series-windows.html)

### 3. Follow the document and install the following services in the microservices folder.
- Ollama: [doc](../microservices/ollama/windows/README.md)
- Text to speech: [doc](../microservices/speech-to-text/windows/README.md)
- Speech to text: [doc](../microservices/text-to-speech/windows/README.md)

### 4. Install RAG Toolkit 
#### 4.1 Install backend
Double click on the `install-backend.bat`

#### 4.2 Install UI
Double click on the `install-ui.bat`

### 5. Run application
#### 5.1 Start Ollama by following the [doc](../microservices/ollama/windows/README.md)

#### 5.2 Start Text to speech by following the [doc](../microservices/speech-to-text/windows/README.md)

#### 5.3 Start Speech to text by following the [doc](../microservices/text-to-speech/windows/README.md)

#### 5.4 Start RAG Toolkit
Double click on the `run.bat`

</details>


## FAQ
1. Changing the inference device for embedding model. Supported device: ["CPU", "GPU"]
```bash
# Example: Loading embedding model on GPU device
export EMBEDDING_DEVICE=GPU
```
2. Changing the inference device for reranker model. Supported device: ["CPU", "GPU"]
```bash
# Example: Loading reranker model on GPU device
export RERANKER_DEVICE=GPU
```

## Limitations
1. Current speech-to-text feature only work with localhost.
2. RAG documents will use all the documents that are uploaded.

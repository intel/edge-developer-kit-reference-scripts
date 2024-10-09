# LLM RAG Toolkit

## Requirements
### Validated hardware
* CPU: 13th generations of Intel Core processors and above
* GPU: Intel® Arc™ graphics
* RAM: 32GB
* DISK: 128GB

### Application ports
Please ensure that you have these ports available before running the applications.
| Apps    | Port |
|---------|------|
| UI      | 8010 |
| Backend | 8011 |
| Serving | 8012 |

## Quick Start
### Prerequisite
If you are using this bundle without any finetuned model, you **must** follow the steps below before running the setup.

### 1. Install operating system
Install the latest [Ubuntu* 22.04 LTS Desktop](https://releases.ubuntu.com/jammy/). Refer to [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop#1-overview) if needed.

<a name="hf-token-anchor"></a>
### 2. Create a Hugging Face account and generate an access token. For more information, please refer to [link](https://huggingface.co/docs/hub/en/security-tokens).

<a name="hf-access-anchor"></a>
### 3. Login to your Hugging Face account and browse to [mistralai/Mistral-7B-Instruct-v0.3](https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.3) and click on the `Agree and access repository` button.

### 4. Clone repository
This step will clone the repository.
```bash
sudo apt install git
git clone https://github.com/intel/edge-developer-kit-reference-scripts
```

### 5. Go to the LLM RAG Toolkit use case directory
This step will redirect user to the current platform setup directory.
```bash
cd edge-developer-kit-reference-scripts/usecases/llm/rag-toolkit
```

### 6. Run the setup script
This step will download all the dependencies needed to run the application.
```bash
./install.sh
```

### 7. Start all the services
Run the script to start all the services. During the first time running, the script will download some assets required to run the services, please ensure you have internet connection.
```bash
./run.sh
```
## Docker Setup
### Prerequisite
1. Docker and docker compose should be setup before running the commands below. Refer to [here](https://docs.docker.com/engine/install/) to setup docker.
1. Install necessary GPU drivers.
   - Refer to [here](../../../gpu/arc/dg2/README.md) to setup GPU drivers


### 1. Setup env
Set the INSTALL_OPTION in env file. 

1 = VLLM (OpenVINO - CPU)
  - Please also provide HF_TOKEN if using this option. Refer [here](#hf-token-anchor) to create a token.
  - Ensure the hugging face token has access to Mistral 7b instruct v0.3 model. Refer [here](#hf-access-anchor) to get access to model.

2 [default] = OLLAMA (SYCL LLAMA.CPP - CPU/GPU)
```bash
cp .env.template .env
```

### 2. Build docker container
```bash
docker compose build
```
 
### 3. Start docker container
```bash
docker compose up -d
```

## FAQ
### Utilize NPU in AI PC
The Speech to Text model inference can be offloaded on the NPU device on an AI PC. Edit the `ENCODER_DEVICE` to *NPU* in `backend/config.yaml` to run the encoder model on NPU. *Currently only encoder model is supported to run on NPU device*
```
# Example:
STT:
  MODEL_ID: base
  ENCODER_DEVICE: NPU # <- Edit this line to NPU
  DECODER_DEVICE: CPU
```

### Uninstall the app
```bash
./uninstall.sh
```

### Environmental variables
You can change the port of the backend server api to route to specific OpenAI compatible server running as well as the serving port.
| Environmental variable |       Default Value      |
|------------------------|--------------------------|
| OPENAI_BASE_URL        | http://localhost:8012/v1 |
| SERVER_HOST            |          0.0.0.0         |
| SERVER_PORT            |           8011           |

## Limitations
1. Current speech-to-text feature only work with localhost.
2. RAG documents will use all the documents that are uploaded.

## Troubleshooting
1. If you have error to run the applications, you can refer to the log files in the logs folder.

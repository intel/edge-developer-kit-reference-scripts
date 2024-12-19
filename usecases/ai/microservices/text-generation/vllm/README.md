# VLLM OpenVINO

## Requirements

### Validated Hardware Requirements
- **CPU:** 13th generation Intel Core processors or newer
- **GPU:** Intel® Arc™ graphics
- **RAM:** 32GB (may vary based on model size)
- **Disk:** 128GB (may vary based on model size)

## Quick Start

### 1. Install Operating System
Install the latest [Ubuntu 22.04 LTS Desktop](https://releases.ubuntu.com/jammy/). Refer to the [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop#1-overview) if needed.

### 2. Install GPU Driver (Optional)
If you plan to use a GPU for inference, install the appropriate GPU driver:
- **Intel® Arc™ A-Series Graphics:** [Installation Guide](https://github.com/intel/edge-developer-kit-reference-scripts/tree/main/gpu/arc/dg2)
- **Intel® Data Center GPU Flex Series:** [Installation Guide](https://github.com/intel/edge-developer-kit-reference-scripts/tree/main/gpu/flex/ats)

### 3. Set Up Docker
Follow the instructions [here](https://docs.docker.com/engine/install/) to install Docker and Docker Compose.

### 4. Build the OpenVINO VLLM Docker Image
```bash
docker build -t ov-vllm .
```

### 5. Run the OpenVINO VLLM container
By default, on the container launch, it 
* **CPU**
```bash
docker run -it --rm \
    -p 8000:8000 \
    -e DEFAULT_MODEL_ID=Qwen/Qwen2.5-7B-Instruct \
    -e MODEL_PRECISION=int4 \
    -e SERVED_MODEL_NAME=ov-vllm \
    -e MAX_MODEL_LEN=2048 \
    -e VLLM_OPENVINO_DEVICE=CPU \
    -e VLLM_OPENVINO_KVCACHE_SPACE=8 \
    -e VLLM_OPENVINO_CPU_KV_CACHE_PRECISION=u8 \
    -e VLLM_OPENVINO_ENABLE_QUANTIZED_WEIGHTS=ON \
    -v ./data:/usr/src/app/data \
    ov-vllm
```

* **GPU**
```bash
export RENDER_GROUP_ID=$(getent group render | cut -d: -f3)
docker run -it --rm \
    --group-add $RENDER_GROUP_ID \
    --device /dev/dri:/dev/dri \
    -p 8000:8000 \
    -e DEFAULT_MODEL_ID=Qwen/Qwen2.5-7B-Instruct \
    -e MODEL_PRECISION=int4 \
    -e SERVED_MODEL_NAME=ov-vllm \
    -e MAX_MODEL_LEN=2048 \
    -e GPU_MEMORY_UTILIZATION=0.9 \
    -e VLLM_OPENVINO_DEVICE=GPU \
    -e VLLM_OPENVINO_KVCACHE_SPACE=8 \
    -e VLLM_OPENVINO_CPU_KV_CACHE_PRECISION=u8 \
    -e VLLM_OPENVINO_ENABLE_QUANTIZED_WEIGHTS=ON \
    -v ./data:/usr/src/app/data \
    ov-vllm
```

### 6. Test the OpenVINO VLLM with chat completion API
```bash
curl "http://localhost:8000/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "ov-vllm",
        "messages": [
            {
                "role": "system",
                "content": "You are a helpful assistant."
            },
            {
                "role": "user",
                "content": "What is AI?"
            }
        ],
        "stream": true
    }'
```


## FAQs
### 1. How can I replace or use my own model?
1. Convert the model into OpenVINO format. Refer to this [link](https://docs.openvino.ai/2024/learn-openvino/llm_inference_guide/genai-model-preparation.html) for more information.
2. After the model convertion steps, place the model in the following following file structures.
```bash
.
├── data
│   └── ov_model
│       ├── added_tokens.json
│       ├── config.json
│       ├── generation_config.json
│       ├── merges.txt
│       ├── openvino_model.bin
│       ├── openvino_model.xml
│       ├── special_tokens_map.json
│       ├── tokenizer_config.json
│       ├── tokenizer.json
│       └── vocab.json
├── Dockerfile
├── entrypoint.sh
└── README.md
```

### 2. How can I change the default model after it has been run once?
1. Delete the existing model located in `./data/ov_model`.
```bash
rm -rf ./data/ov_model
```
2. Rerun the `docker run` command to load and quantize the new model.

### 3. How can I avoid redownload the model everytime to convert and quantize the model?
1. Mount the huggingface cache path into the container
```bash
-v $HOME/.cache/huggingface:/home/intel/.cache/huggingface
```
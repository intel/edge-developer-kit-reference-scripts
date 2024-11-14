# LLM Finetuning Benchmark
A script to benchmark the performance for PEFT finetuning LLM model on Intel GPU. \
Supported PEFT methods:
* QLORA

## Requirement
### Hardware
* CPU: 13th Gen Intel® Core™ Processor Family or 4th Gen Xeon Scalable Processors and above
* GPU: Intel® Arc™ A770 Graphics (16GB)
* RAM: 64GB
* SSD: 512GB

## Quick Start
### 1. Install operating system
Install the latest [Ubuntu* 22.04 LTS Desktop](https://releases.ubuntu.com/jammy/). Refer to [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop#1-overview) if needed.

### 2. Install Intel® GPU driver: [link](https://github.com/intel/edge-developer-kit-reference-scripts/tree/main/gpu/arc/dg2)

### 3. Intel® oneAPI Base Toolkit (version 2024.2.0): [link](https://www.intel.com/content/www/us/en/developer/tools/oneapi/base-toolkit-download.html?operatingsystem=linux&linux-install-type=offline)

### 4. Set up and create Python 3.11 virtual environment
```bash
sudo apt update
sudo apt install -y python3.11 python3.11-venv
python3.11 -m venv .venv
```

### 5. Installing Python packages
```bash
source .venv/bin/activate
python3 -m pip install --pre --upgrade ipex-llm[xpu] --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/
python3 -m pip install torch==2.1.0.post2 torchvision==0.16.0.post2 torchaudio==2.1.0.post2 intel-extension-for-pytorch==2.1.30.post0 oneccl_bind_pt==2.1.300+xpu --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/
python3 -m pip install setuptools==69.5.1 numpy==1.26.4
python3 -m pip install transformers==4.43.3 accelerate==0.33.0 datasets==2.20.0 peft==0.12.0 bitsandbytes==0.43.2 scipy==1.14.0 fire==0.6.0 trl==0.9.6
```

### 6. Activate Python 3.11 environment and run the finetuning benchmark scripts
```bash
source .venv/bin/activate
./benchmark.sh
```

### 7. Verify the training efficiency (token/secs) in the logs folder
```bash
tail -f logs/training.log
```

## Disclamer
This script is just used for getting the training efficiency related usage and don't guarantee convergence of training.

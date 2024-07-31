# OpenVINO™ Bert Model Benchmarking
Benchmark OpenVINO™  bert model

## Steps
### 1. Setup OpenVINO™
Setup OpenVINO™
```bash
./setup_ov.sh
```
Installation is completed when you see this message:
> ✓ OpenVINO™  configured

### 2. Benchmark 

Benchmark bert-base-cased model (FP32)
```bash
#Python virtual environment to testing bert openvino model
source bert_ov_venv/bin/activate

#CPU
numactl -C 0 benchmark_app -m models/bert-base-cased.xml -d CPU -hint latency -shape "[1, 512]"
#GPU
numactl -C 0 benchmark_app -m models/bert-base-cased.xml -d GPU -hint latency -shape "[1, 512]"

#Deactivate virtual environment
deactivate

```

Benchmark quantized bert-base-cased model (INT8)
```bash

#Python virtual environment to testing bert openvino model
source bert_ov_venv/bin/activate

#CPU
numactl -C 0 benchmark_app -m models/quantized_bert_base_cased.xml -d CPU -hint latency -shape "[1, 512]"
#GPU
numactl -C 0 benchmark_app -m models/quantized_bert_base_cased.xml -d GPU -hint latency -shape "[1, 512]"

#Deactivate virtual environment
deactivate
```

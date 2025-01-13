# Image Classification Microservice

## Hardware Validated

Platform | Detail
--- | ---
Meteor Lake | Intel® Core™ Ultra 7 155H

## Model Validated

Model | Format | Device
--- | --- | ---
ResNet50 | OpenVINO IR | CPU, GPU, NPU
MobileNetv2 | OpenVINO IR | CPU, GPU, NPU

## Software Ingredient 

Package | Version
--- | ---
openvino-dev | 2024.6.0
grpcio | 1.69.0
tensorflow-serving-api | 2.17.1
opencv-python | 4.10.0.84

## Prerequisites
- [Docker Engine](https://docs.docker.com/engine/install/ubuntu/)

- Optional: [GPU Driver](https://github.com/intel/edge-developer-kit-reference-scripts/blob/main/gpu/arc/dg2/usecases/openvino/install_gpu.sh)

## Prepare model

- Install OpenVINO Development Tools

  ```
  python3 -m venv env

  source env/bin/activate
  
  pip install -U pip
  pip install -r requiremenets.txt
  ```

- Download model from Open Model Zoo

  ```
  omz_downloader --name <model_name>

  Example:

  omz_downloader --name resnet-50-pytorch
  ```

- Convert model to OpenVINO IR format

  ```
  omz_converter --name <model_name> 

  Example:

  omz_converter --name resnet-50-pytorch 
  ```

- Follow [OpenVINO™ Model Server model folder structure](https://docs.openvino.ai/2024/openvino-workflow/model-server/ovms_docs_models_repository.html)

  ```
  Example:

  models/
  └── resnet-50-pytorch
        └── 1
          ├── resnet-50-pytorch.xml
          └── resnet-50-pytorch.bin
  ```

## Prepare and run docker images 

- Download docker image 

  ```
  docker pull openvino/model_server:latest
  ```

- Start the container

  ```
  docker run -d -u $(id -u) --rm -v ${PWD}/<model_directory>:<model_directory> -p 9000:9000 openvino/model_server:latest --model_name <model_name> --model_path <model_path> --port 9000

  Example:

  docker run -d -u $(id -u) --rm -v ${PWD}/models:/models -p 9000:9000 openvino/model_server:latest --model_name resnet --model_path /models/resnet-50-pytorch --port 9000
  ```

## Testing on CPU

- Get example client components from Model Server

  ```
  git clone https://github.com/openvinotoolkit/model_server.git

  cd model_server/demos/image_classification/python
  ```

- Run inference

  ```
  python3 image_classification.py --grpc_port 9000 --model_name <model_name> --input_name <model_input_name> --output_name <model_output_name> --images_list ../input_images.txt

  Example:

  python3 image_classification.py --grpc_port 9000 --model_name resnet --input_name data --output_name prob --images_list ../input_images.txt
  ```

## Testing on GPU

- Download docker image that contains GPU dependencies

  ```
  docker pull openvino/model_server:latest-gpu
  ```

- Start container

  ```
  docker run -d --device=/dev/dri --group-add=$(stat -c "%g" /dev/dri/render* | head -n 1) -u $(id -u) --rm -v ${PWD}/<model_directory>:<model_directory> -p 9000:9000 openvino/model_server:latest-gpu --model_name <model_name> --model_path <model_path> --port 9000 --target_device <GPU or AUTO>

  Example:

  docker run -d --device=/dev/dri --group-add=$(stat -c "%g" /dev/dri/render* | head -n 1) -u $(id -u) --rm -v ${PWD}/models:/models -p 9000:9000 openvino/model_server:latest-gpu --model_name resnet --model_path /models/resnet-50-pytorch --port 9000 --target_device GPU
  ```

- Run inference

  ```
  python3 image_classification.py --grpc_port 9000 --model_name <model_name> --input_name <model_input_name> --output_name <model_output_name> --images_list ../input_images.txt

  Example:

  python3 image_classification.py --grpc_port 9000 --model_name resnet --input_name data --output_name prob --images_list ../input_images.txt
  ```

## Testing on NPU

- Build docker image with NPU dependencies

  ```
  cd model_server
  make release_image NPU=1
  ```

- Start container

  ```
  docker run -d --device=/dev/accel --group-add=$(stat -c "%g" /dev/dri/render* | head -n 1) -u $(id -u) --rm -v ${PWD}/<model_directory>:<model_directory> -p 9000:9000 openvino/model_server:latest --model_name <model_name> --model_path <model_path> --port 9000 --target_device NPU

  Example:

  docker run -d --device=/dev/accel --group-add=$(stat -c "%g" /dev/dri/render* | head -n 1) -u $(id -u) --rm -v ${PWD}/models:/models -p 9000:9000 openvino/model_server:latest --model_name resnet --model_path /models/resnet-50-pytorch --port 9000 --target_device NPU
  ```

- Run inference

  ```
  python3 image_classification.py --grpc_port 9000 --model_name <model_name> --input_name <model_input_name> --output_name <model_output_name> --images_list ../input_images.txt

  Example:

  python3 image_classification.py --grpc_port 9000 --model_name resnet --input_name data --output_name prob --images_list ../input_images.txt
  ```

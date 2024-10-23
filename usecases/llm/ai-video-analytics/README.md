# AI Video Analytics
A sample application to perform semantic search and face identification with embedding search on uploaded video.

## Example
![Alt Text](./assets/example.gif)

## Requirements
### Validated hardware
* CPU: Intel® Core™ Ultra 7 processors
* RAM: 32GB
* DISK: 128GB

### Application ports
Please ensure that you have these ports available before running the applications.

| Apps     | Port |
|----------|------|
| Server   | 5980 |

## Quick Start
### 1. Install operating system
Install the latest [Ubuntu* 22.04 LTS Desktop](https://releases.ubuntu.com/jammy/). Refer to [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop#1-overview) if needed.

### 2. Clone repository
This step will clone the repository
```
sudo apt install git
git clone https://github.com/intel/edge-developer-kit-reference-scripts
```

### 3. Go to the AI Video Analytics use case directory
This step will redirect user to the current platform setup directory.
```bash
cd edge-developer-kit-reference-scripts/usecases/llm/ai-video-analytics
```
### 4. Model Preparation
Download face detection and face regression models
```bash
sudo apt-get update
sudo apt-get install -y wget
mkdir -p ./data/model/facial_recognition
# Download face detection model
wget -O ./data/model/facial_recognition/face-detection-retail-0004.xml https://storage.openvinotoolkit.org/repositories/open_model_zoo/2023.0/models_bin/1/face-detection-retail-0004/FP32/face-detection-retail-0004.xml
wget -O ./data/model/facial_recognition/face-detection-retail-0004.bin https://storage.openvinotoolkit.org/repositories/open_model_zoo/2023.0/models_bin/1/face-detection-retail-0004/FP32/face-detection-retail-0004.bin
# Download face regression model
wget -O ./data/model/facial_recognition/landmarks-regression-retail-0009.xml https://storage.openvinotoolkit.org/repositories/open_model_zoo/2023.0/models_bin/1/landmarks-regression-retail-0009/FP32/landmarks-regression-retail-0009.xml
wget -O ./data/model/facial_recognition/landmarks-regression-retail-0009.bin https://storage.openvinotoolkit.org/repositories/open_model_zoo/2023.0/models_bin/1/landmarks-regression-retail-0009/FP32/landmarks-regression-retail-0009.bin
```
### 5. Setup environment
Setup the application dependencies
```bash
sudo apt-get update
sudo apt-get install -y python3-venv
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -U pip
python3 -m pip install -r requirements.txt
```

### 6. Run the application
Run the following command to start the app
```bash
source .venv/bin/activate
python3 app.py
```

### 7. Access the App
1. Open browser Google Chrome
2. Access http://localhost:5980

## Docker Setup
### Prerequisite
1. Docker and docker compose should be setup before running the commands below. Refer to [here](https://docs.docker.com/engine/install/) to setup docker.

### 1. Build docker container
```
docker compose build
```

### 2. Start docker container
```
docker compose up -d
```
### 3. Access the App
1. Open browser Google Chrome
2. Access http://localhost:5980

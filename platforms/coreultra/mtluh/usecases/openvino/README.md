# Intel® Distribution of OpenVINO™ Toolkit

## Requirement
### Validated Hardware
- [Seavo McLaren Island AIoT Developer Kit](https://www.seavo.com/en/pir_devkit/)

## Pre-requisites
- Platform MTL-UH reference setup script installed. Refer to [README.md](../../README.md) 
- Docker version 24 or later installed

## Quick Start
### 1. Go to OpenVINO™ Usecase Directory
```bash
cd edge-developer-kit-reference-scripts/platforms/coreultra/mtluh/usecases/openvino
```

### 2. Run the Setup Script
This script will create 2 docker images: OpenVINO™ docker image and OpenVINO™ Notebooks docker image.
```bash
./setup.sh
```
During installation, it may ask you to reboot your system. Reboot the system and run `./setup.sh` again. Installation is completed when you see this message:
> ✓ OpenVINO™ use case Installed

When you run the command `docker images`, you can see the following docker images:
```
REPOSITORY                       TAG       IMAGE ID       CREATED        SIZE
openvino_notebook/ubuntu22_dev   latest    71a34103833a   24 hours ago   4.69GB
openvino_npu/ubuntu22_dev        latest    a0cd6a9fe16e   24 hours ago   3.95GB
```

## Run Docker Image
### OpenVINO™ with NPU (Intel® AI Boost)
1. Run this command to launch docker container with OpenVINO™ image and link to your working directory. For this example, the working directory is in /home/user/workspace and it mount to container /data/workspace directory.

```bash
docker run -it -d --name openvino_app -u root -v /etc/group:/etc/group --device=/dev/dri --device=/dev/accel --group-add=$(stat -c "%g" /dev/dri/render* | head -n 1) -v /usr/bin:/usr/bin -v /home/user/workspace:/data/workspace -w /data/workspace openvino_npu/ubuntu22_dev:latest
```

- --name: container name
- -v: mount from local source directory to container destination directory
- --device: Add device to container
- --group-add: Add additional groups
- -w: The default working directory inside the container

2. Run the following command to login into container:
```bash
docker exec -it openvino_app /bin/bash
```

3. Now you can run your application with OpenVINO™

### OpenVINO™ Notebooks
1. Run this command to launch OpenVINO™ Notebooks
```bash
./launch_notebooks.sh
```
2. Copy the URL printed in the terminal and open in a browser. Example output you will see in terminal:
```
    To access the server, open this file in a browser:
        file:///opt/app-root/src/.local/share/jupyter/runtime/jpserver-20-open.html
    Or copy and paste one of these URLs:
        http://8adf267b0a6a:8888/lab?token=7d150b3a8d4157f1068c85d582eff346cce28e24cd2e9a85
        http://127.0.0.1:8888/lab?token=7d150b3a8d4157f1068c85d582eff346cce28e24cd2e9a85
```
3. Open your browser and paste the URL. You will see openvino_notebooks directory and it has a lot of sample to try out.

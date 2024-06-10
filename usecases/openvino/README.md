# Intel® Distribution of OpenVINO™ toolkit

## Requirement
### Validated Hardware
- Asrock IEPF-9030S-EY4 + Intel® Arc™ A770 Graphics

## Pre-requisites
- Platform BKC or GPU BKC installed. Refer to [README.md](../../README.md) 
- Docker version 24 or later installed

## Quick Start
### 1. Go to OpenVINO™ usecase directory
```bash
cd edge-developer-kit-reference-scripts/usecases/openvino
```

### 2. Run the setup script
This script will create 2 docker images: OpenVINO™ docker image and OpenVINO™ Notebooks docker image.
```bash
./setup.sh
```
During installation, it may ask you to reboot your system. Reboot the system and run `./setup.sh` again. Installation is completed when you see this message:
> ✓ OpenVINO™ use case Installed

When you run command `docker images`, you can see the following example:
```
REPOSITORY                                  TAG       IMAGE ID       CREATED          SIZE
openvino_notebooks                          latest    5d337de8990a   46 minutes ago   6.46GB
openvino/ubuntu22_dev                       latest    d283c46d13e2   7 weeks ago      3.92GB
```

## Run Docker Image
### OpenVINO™ Toolkit
1. Run this command to launch docker container with OpenVINO™ image and link to your working directory. For this instance, the working directory is in /home/user/workspace and it mount to container /data/workspace directory.
```bash
docker run -it -d --name openvino_app -v /etc/group:/etc/group --device=/dev/dri --group-add=$(stat -c "%g" /dev/dri/render* | head -n 1) -v /usr/bin:/usr/bin -v /home/user/workspace:/data/workspace -w /data/workspace openvino/ubuntu22_dev:latest
```

- --name: container name
- -v: mount from local source directory to container destination directory
- --device: Add device to container
- --group-add: Add additional groups
- -w: The default working directory inside the container

2. Run following command to login into container:
```bash
docker exec -it openvino_app /bin/bash
```

3. Now you can run your application with OpenVINO™

### OpenVINO™ Notebooks
1. Run this command to launch OpenVINO™ Notebooks
```bash
docker run -it --name test_notebooks -v /etc/group:/etc/group  --device=/dev/dri --group-add=$(stat -c "%g" /dev/dri/render* | head -n 1) -p 8888:8888 openvino_notebooks
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
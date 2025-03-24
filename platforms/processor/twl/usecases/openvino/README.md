# Intel® Distribution of OpenVINO™ toolkit

## Requirement
### Validated Hardware
- AAEON RS-UPN-ADLN355-A10-0864

## Pre-requisites
- Platform reference setup script installed. Refer to [README.md](../../README.md) 
- Docker version 24 or later installed

## Quick Start
### 1. Run the setup script
This script will create 2 docker images: OpenVINO™ docker image and OpenVINO™ Notebooks docker image.
```bash
source setup.sh
```
During installation, it may ask you to reboot your system. Reboot the system and run `source setup.sh` again. Installation is completed when you see this message:
> ✓ OpenVINO™ use case Installed

When you run command `docker images`, you can see the following example:
```
REPOSITORY                                  TAG       IMAGE ID       CREATED          SIZE
openvino_notebook/ubuntu24_dev             latest    5d337de8990a   46 minutes ago   5.57GB
openvino_igpu/ubuntu24_dev                 latest    d283c46d13e2   7 weeks ago      4.92GB
```

## Run Docker Image
### OpenVINO™ Toolkit
1. Run this command to launch docker container with OpenVINO™ image and link to your working directory. For this instance, the working directory is in /home/user/workspace and it mount to container /data/workspace directory.
```bash
docker run -it -u root -d --name openvino_app -v /etc/group:/etc/group --device=/dev/dri --group-add=$(stat -c "%g" /dev/dri/render* | head -n 1) -v /usr/bin:/usr/bin -v /home/user/workspace:/data/workspace -w /data/workspace openvino_igpu/ubuntu24_dev:latest
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
./launch_notebooks.sh
```
2. Copy the URL printed in the terminal and open in a browser. Example output you will see in terminal:
```
    To access the server, open this file in a browser:
        file:///root/.local/share/jupyter/runtime/jpserver-9-open.html
    Or copy and paste one of these URLs:
        http://b8c40fbc24fb:8888/lab?token=b149317e478f523c06600b78b67abf9db230a8af709009e7
        http://127.0.0.1:8888/lab?token=b149317e478f523c06600b78b67abf9db230a8af709009e7
```
3. Open your browser and paste the URL. You will see openvino_notebooks directory and it has a lot of sample to try out.

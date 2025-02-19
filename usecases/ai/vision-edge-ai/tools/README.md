# Intel Platform Setup Tool

## Overview
This folder contains installation scripts designed to streamline the setup of essential drivers, kernel modules, and Docker on Intel platforms. 
This tool simplifies the installation process for developers working with Intel hardware, ensuring all necessary components are properly installed and configured.

## Supported Distributions
Currently, the installer supports only the following Ubuntu versions:
- **Ubuntu 22.04 (Jammy Jellyfish)**
- **Ubuntu 24.04 (Noble Numbat)**
- **Ubuntu 24.10 (Oracular Oriole)**

## Features
- Automatic installation of Intel kernel drivers
- Setup of Intel Graphics and NPU (Neural Processing Unit) drivers
- Docker installation and configuration
- Support for configurable environment variables
- Optional cleaning of previously installed components

## Environment Variables
The installer provides configurable environment variables for flexibility:

- **`KERNEL_VERSION`**: Specifies the kernel version to be installed. Default: `v6.14-rc1`.
  ```bash
  export KERNEL_VERSION="v6.14-rc1"
  ```

- **`NPU_VERSION`**: Specifies the Intel NPU driver version. Default: `1.13.0`.
  ```bash
  export NPU_VERSION="1.13.0"
  ```

## Prerequisites
Ensure you have the following before running the installer:
- A system running one of the supported Ubuntu versions
- `sudo`/root access for installation
- Internet connectivity

## Installation
To install the Intel Stack, follow these steps:

2. Install all dependencies at once:
   ```bash
   bash ./install.sh
   ```

Alternatively, you can install each component separately:

- **Install only the kernel:**  
  ```bash
  bash ./install_kernel.sh
  ```

- **Install only the GPU drivers:**  
  ```bash
  bash ./install_gpu_drivers.sh
  ```

- **Install only the GPU and NPU drivers:**  
  ```bash
  bash ./install_npu_drivers.sh
  ```


- **Install only Docker:**  
  ```bash
  bash ./install_docker.sh
  ```

## Cleaning Up Previous Installations
If you want to remove previously installed kernel, GPU, NPU drivers, or Docker, use the `--clean` flag:

```bash
bash ./install_kernel.sh --clean
bash ./install_gpu_drivers.sh --clean
bash ./install_npu_drivers.sh --clean
bash ./install_docker.sh --clean
```

This will remove any existing installations and start a fresh installation process.

## Usage
After installation, you can verify the installed components with:

```bash
lsmod | grep xe
docker --version
nvcc --version
```

## Author
**Jamal El Youssefi**  
Email: [jamal.el.youssefi@intel.com](mailto:jamal.el.youssefi@intel.com)

---

#  Intel® Arc™ B-Series Graphics (Products formerly Battlemage)

## Requirement
### Validated Hardware
- Asrock iEPF-9030S-EY4 + Intel® Arc™ B580 Graphics

## Pre-requisite
- Enable resizable bar option in BIOS settings

## Quick Start
### 1. Install operating system
Install the latest [Ubuntu* 24.04 LTS Desktop](https://releases.ubuntu.com/noble/). Refer to [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop#1-overview) if needed.

> **Note**
> Please ensure that your display cable is connected to the dgpu

### 2. Download scripts
This step will download the setup script to your current directory
```bash
wget https://raw.githubusercontent.com/intel/edge-developer-kit-reference-scripts/refs/heads/main/gpu/bmg/setup.sh
```

### 3. Run the setup script
This step will configure the basic setup of the platform. Make sure to run the script with **privileged access** and ensure that all of the requirements have been met before proceeding to the next step.
```bash
sudo bash setup.sh
```
After completing the setup, please reboot the system in order for the setup to be completed.

## Next Steps
1. [Intel® Distribution of OpenVINO™ Toolkit](usecases/openvino/README.md)
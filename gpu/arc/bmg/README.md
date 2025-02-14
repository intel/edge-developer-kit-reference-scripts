#  Intel® Arc™ B-Series Graphics (Products formerly Battlemage)

## Requirement
### Validated Hardware
- Asrock iEPF-9030S-EY4 + Intel® Arc™ B580 Graphics
- Asrock iEPF-10000S Series + Intel® Arc™ B580 Graphics

## Pre-requisite
- Enable resizable bar option in BIOS settings

## Quick Start
### 1. Install operating system
Install the latest [Ubuntu* 24.04 LTS Desktop](https://releases.ubuntu.com/noble/). Refer to [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop#1-overview) if needed.

> **Note**
> Please ensure that your display cable is connected to the dgpu

### 2. Download and run setup script
This step will download and run the setup script to your current directory
```bash
sudo bash -c "$(wget -qLO - https://raw.githubusercontent.com/intel/edge-developer-kit-reference-scripts/refs/heads/main/gpu/arc/bmg/setup.sh)"
```

After completing the setup, please reboot the system in order for the setup to be completed.

## Next Steps
1. [Intel® Distribution of OpenVINO™ Toolkit](usecases/openvino/README.md)

# Intel® Core™ Ultra Processors (Series 2) (Products formerly known as Lunar Lake)

## Requirements

#### Validated Hardware
ASUSTeK COMPUTER INC. NUC14LNK

## Quick Start

### 1. Install the Operating System

Install the latest [Ubuntu* 24.04 LTS Desktop](https://releases.ubuntu.com/noble/). Refer to the [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop) if needed.


### 2. Run the Setup Script

This step will configure the basic setup of the platform. Make sure all of the requirements have been met before proceeding to the next step.

```bash
sudo bash -c "$(wget -qLO - https://raw.githubusercontent.com/intel/edge-developer-kit-reference-scripts/refs/heads/main/platforms/coreultra/lnl/setup.sh)"
```
When installation is completed, you may be required to reboot your system. Reboot the system. 
Installation is completed when you see this message:
> ✓ Platform configured

> System reboot is required.

## Next Step
1. [Intel® Distribution of OpenVINO™ Toolkit](./usecases/openvino/README.md)

## Known Issues
1. When swap/turn off the monitor display, the screen may become unresponsive and fail to wake up, necessitating a hard reboot of the system.

    
2. When screen blank time is set in the power-saving options and screen blank happened, the screen may become unresponsive and fail to wake up,necessitating a hard reboot of the system.

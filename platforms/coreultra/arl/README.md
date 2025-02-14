# Intel® Core™ Ultra Processors (Series 2) (Products formerly known as Arrow Lake)

## Requirements

#### Validated Hardware
- Innodisk Arrow Island
- IEI TANK-XM813

## Quick Start

### 1. Install operating system

Install the latest [Ubuntu* 24.04 LTS Desktop](https://releases.ubuntu.com/noble/). Refer to the [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop) if needed.

### 2. Download scripts

This step will download all reference scripts from the repository.

```bash
sudo apt install git
git clone https://github.com/intel/edge-developer-kit-reference-scripts
```

### 3. Go to specific setup directory

This step will redirect user to the current platform setup directory

```bash
cd edge-developer-kit-reference-scripts/platforms/coreultra/arl
```

### 4. Run setup script

This step will configure the basic setup of the platform. Make sure all of the requirements have been met before proceeding to the next step.

```bash
./setup.sh
```
During installation, it may ask you to reboot your system. Reboot the system and run `./setup.sh` again. Installation is completed when you see this message:
> ✓ Platform configured

## Next Step
1. [Intel® Distribution of OpenVINO™ Toolkit](./usecases/openvino/README.md)
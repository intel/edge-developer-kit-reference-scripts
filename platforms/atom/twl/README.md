# Intel® Core™ Processor N-series (Products formerly known as Twin Lake)

## Requirements

#### Validated Hardware
- AAEON RS-UPN-ADLN355-A10-0864

## Quick Start

### 1. Install operating system

Install the latest [Ubuntu* Desktop 24.04.1 LTS](https://ubuntu.com/download/desktop/thank-you?version=24.04.1&architecture=amd64&lts=true). Refer to the [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop) if needed.

### 2. Download scripts

This step will download all reference scripts from the repository.

```bash
git clone https://github.com/intel/edge-developer-kit-reference-scripts
```

### 3. Go to specific setup directory

This step will redirect user to the current platform setup directory

```bash
cd edge-developer-kit-reference-scripts/platforms/atom/twl
```

### 4. Run setup script

This step will configure the basic setup of the platform. Make sure all of the requirements have been met before proceed to the next step.

```bash
./setup.sh
```

During installation, it may ask you to reboot your system. Reboot the system and run `./setup.sh` again. Installation is completed when you see this message:

> ✓ Platform configured


## Next Steps

Refer to the available use cases and examples below

1. [Setup Intel® Distribution of OpenVINO™ toolkit in Docker](usecases/openvino/README.md)
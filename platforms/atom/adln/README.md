# Intel® Processor (Products formerly Alder Lake-N)

Intel® Processor (Products formerly Alder Lake-N)

## Requirements

#### Validated Hardware
- [AAEON UP Squared Pro 7000 (UPN-ADLNI3-A10-1664)](https://www.aaeon.com/en/p/up-board-up-squared-pro-7000)

## Quick Start

### 1. Install operating system

Install latest [Ubuntu 22.04 LTS Desktop for Intel IoT platforms](https://cdimage.ubuntu.com/releases/jammy/release/inteliot/). Refer to [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop) if needed.

### 2. Download scripts

This step will download all reference scripts from the repository.

```bash
git clone https://github.com/intel/edge-developer-kit-reference-scripts
```

### 3. Go to specific setup directory

This step will redirect user to the current platform setup directory

```bash
cd edge-developer-kit-reference-scripts/platforms/atom/adln
```

### 4. Run setup script

This step will configure the basic setup of the platform. Make sure all of the requirements have been met before proceed with the step below.

```bash
./setup.sh
```

During installation, it may ask you to reboot your system. Reboot the system and run `./setup.sh` again. Installation is completed when you see this message:

> ✓ Platform configured


## Next Steps

Refer to available use cases and examples below

1. [OpenVINO](https://docs.openvino.ai/)
2. [Intel® Edge Software Hub](https://www.intel.com/content/www/us/en/developer/topic-technology/edge-5g/edge-solutions/overview.html) 


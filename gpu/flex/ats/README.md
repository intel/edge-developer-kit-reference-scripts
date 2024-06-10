# Intel® Data Center GPU Flex Series (Products formerly known as Arctic Sound)

## Requirement
### Validated Hardware
- [Supermicro SYS-111E-FWTR](https://www.supermicro.com/en/products/system/iot/1u/sys-111e-fwtr) + Intel® Data Center GPU Flex 170

## Quick Start
### 1. Install operating system
Install the latest [Ubuntu* 22.04 LTS Server](https://releases.ubuntu.com/jammy/). Refer to the [Ubuntu Server installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-server#1-overview) if needed.

### 2. Download scripts
This step will download all reference scripts from the repository.
```bash
sudo apt install git
git clone https://github.com/intel/edge-developer-kit-reference-scripts
```

### 3. Go to specific setup directory
This step will redirect user to the current platform setup directory
```bash
cd edge-developer-kit-reference-scripts/gpu/flex/ats/
```

### 4. Run setup script
This step will configure the basic setup of the platform. Make sure all of the requirements have been met before proceeding to the next step.
```bash
./setup.sh
```
During installation, it may ask you to reboot your system. Reboot the system and run `./setup.sh` again. Installation is completed when you see this message:
> ✓ Platform configured

## Next Steps
Refer to the available use cases and examples below
1. [Intel® Distribution of OpenVINO™ Toolkit](../../../usecases/openvino/README.md)
2. [Intel® Edge Software Hub](https://www.intel.com/content/www/us/en/developer/topic-technology/edge-5g/edge-solutions/overview.html)

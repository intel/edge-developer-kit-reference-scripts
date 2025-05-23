# Intel® Core™ Processors (14th gen) (Products formerly known as Raptor Lake-S Refresh)

## Requirement
### Validated Hardware
- [IEI* TANK-XM811AI-RPL AIoT Developer Kit](https://www.ieiworld.com/en/product-ns/model.php?II=8)
- [ASRock Industrial* iEPF-9030S-EW4](https://www.asrockind.com/iEPF-9030S-EW4)

## Quick Start
### 1. Install operating system
Install the latest [Ubuntu* 22.04 LTS Desktop](https://releases.ubuntu.com/jammy/). Refer to [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop#1-overview) if needed.

### 2. Download scripts
This step will download all reference scripts from the repository.
```bash
sudo apt install git
git clone https://github.com/intel/edge-developer-kit-reference-scripts
```

### 3. Go to specific setup directory
This step will redirect user to the current platform setup directory
```bash
cd edge-developer-kit-reference-scripts/platforms/core/rpl/rpls
```

### 4. Run setup script
This step will configure the basic setup of the platform. Make sure all of the requirements have been met before proceeding to the next step.
```bash
sudo ./setup.sh
```
During installation, it may ask you to reboot your system. Reboot the system and run `./setup.sh` again. Installation is completed when you see this message:
> ✓ Platform configured

## Next Steps
Refer to the available use cases and examples below
1. [Intel® Distribution of OpenVINO™ Toolkit](../../../../usecases/ai/openvino/README.md)
2. [Intel® Edge Software Hub](https://www.intel.com/content/www/us/en/developer/topic-technology/edge-5g/edge-solutions/overview.html)

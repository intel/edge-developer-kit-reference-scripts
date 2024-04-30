# Intel® Core™ Processors (14th gen) (Products formerly known as Raptor Lake-S Refresh)

## Requirement
### Validated Hardware
- IEI Tank XM811 with Intel® Core™ i9 processor 14900T

## Quick Start
### 1. Install operating system
Install the latest [Ubuntu* 22.04 LTS Desktop](https://releases.ubuntu.com/jammy/). Refer to [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop#1-overview) if needed.

### 2. Download scripts
This step will download all reference scripts from the repository.
```
git clone https://github.com/intel/edge-developer-kit-reference-scripts
```

### 3. Go to specific setup directory
This step will redirect user to the current platform setup directory
```
cd edge-developer-kit-reference-scripts/platforms/core/rpl/rpls
```

### 4. Run setup script
This step will configure the basic setup of the platform. Make sure all of the requirements have been met before proceeding to the next step.
```
./setup.sh
```
During installation, it may ask you to reboot your system. Reboot the system and run `./setup.sh` again. Installation is completed when you see this message:
> ✓ Platform configured

## Next Steps
Refer to the available use cases and examples below
1. [OpenVINO™](https://docs.openvino.ai/2023.3/home.html)
2. [Intel® Edge Software Hub](https://www.intel.com/content/www/us/en/developer/topic-technology/edge-5g/edge-solutions/overview.html)
3. [Vector Packet Processing](../../../../usecase/netsec/vpp/setup_vpp.md)

# Intel® Arc™ A-Series Graphics (Products formerly known as Alchemist)

## Requirement
### Validated Hardware
- [Asus PE3000G](https://www.asus.com/networking-iot-servers/aiot-industrial-solutions/embedded-computers-edge-ai-systems/pe3000g/) + Intel® Arc™ A370M Graphics

## Quick Start
### 1. Install operating system
Install the latest [Ubuntu* 22.04 LTS Desktop](https://releases.ubuntu.com/jammy/). Refer to [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop#1-overview) if needed.

> **Note**
> Ubuntu* 22.04 installation process may freeze if the primary display is set to dGPU. Some devices for example, the Asus IoT PE3000G, has the default dGPU set as the primary display. To solve this, go to the BIOS menu, select Advanced -> Graphic Configuration -> Primary Display, select 'IGFX'. Save changes and reboot the system. Then, you can proceed to install Ubuntu 22.04 and following the setup script.

> If you wish to use the dGPU as the primary display, go to the BIOS and switch the selection back to 'PEG Slot' or 'AUTO'.


### 2. Download scripts
This step will download all reference scripts from the repository.
```
git clone https://github.com/intel/edge-developer-kit-reference-scripts
```

### 3. Go to specific setup directory
This step will redirect user to the current platform setup directory
```
cd edge-developer-kit-reference-scripts/gpu/arc/dg2
```

### 4. Run setup script
This step will configure the basic setup of the platform. Make sure all of the requirements have been met before proceeding to the next step.
```
./setup.sh
```
During installation, it may ask you to reboot your system. Reboot the system and run `./setup.sh` again. Installation is completed when you see this message:
> ✓ Platform configured

## Next Steps
Refer the to available use cases and examples below
1. [OpenVINO™](https://docs.openvino.ai/2023.3/home.html)
2. [Intel® Edge Software Hub](https://www.intel.com/content/www/us/en/developer/topic-technology/edge-5g/edge-solutions/overview.html)

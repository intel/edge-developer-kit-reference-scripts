# Intel® Core™ Ultra Processors (Products formerly known as Meteor Lake-UH)

## Requirements

#### Validated Hardware
- [Seavo* PIR-1014A AIoT Developer Kit](https://www.seavo.com/en/pir_devkit/)
- [AAEON* UP Xtreme i14](https://up-board.org/up-xtreme-i14/)
- [ASRock Industrial* NUC BOX-155H](https://www.asrockind.com/en-gb/NUC%20BOX-155H)
- [Asus* NUC 14 Pro](https://www.asus.com/displays-desktops/nucs/nuc-mini-pcs/asus-nuc-14-pro/)

## Quick Start

### 1. Install operating system

Install the latest [Ubuntu* 22.04 LTS Desktop](https://releases.ubuntu.com/jammy/). Refer to the [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop) if needed.

### 2. Download scripts

This step will download all reference scripts from the repository.

```bash
sudo apt install git
git clone https://github.com/intel/edge-developer-kit-reference-scripts
```

### 3. Go to specific setup directory

This step will redirect user to the current platform setup directory

```bash
cd edge-developer-kit-reference-scripts/platforms/coreultra/mtluh
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

1. [Intel® Distribution of OpenVINO™ Toolkit](usecases/openvino/README.md)
2. [Intel® Edge Software Hub](https://www.intel.com/content/www/us/en/developer/topic-technology/edge-5g/edge-solutions/overview.html) 
3. [Ollama with Open WebUI on Intel® Discrete GPU](../../../usecases/ai/openwebui-ollama/README.md)
4. [D457 GMSL Camera Enablement on Intel® Core™ Ultra Processor (Products formerly Meteor Lake-UH)](gmsl/d457/README.md)

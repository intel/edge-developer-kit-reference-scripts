# Intel® Core™ Ultra Processors (Series 2) (Products formerly known as Arrow Lake)

## Requirements

#### Validated Hardware
- [Innodisk AXMB-D150 Arrow Island](https://www.innodisk.com/en/blog/intel-core-ultra-series2-reference-kit)
- [IEI TANK-XM813](https://www.ieiworld.com/tw/product/model.php?II=1099)
- [AAEON UP Xtreme ARL](https://up-board.org/up-xtreme-arl/)
- [ASRock Industrial* NUC BOX-255H](https://www.asrockind.com/en-gb/NUC%20BOX-255H)

## Quick Start

### 1. Install the Operating System

Install the latest [Ubuntu* 24.04 LTS Desktop](https://releases.ubuntu.com/noble/). Refer to the [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop) if needed.

### 2. Download the Scripts

This step will download all reference scripts from the repository.

```bash
sudo apt install git
git clone https://github.com/intel/edge-developer-kit-reference-scripts
```

### 3. Go to the Specific Setup Directory

This step will redirect user to the current platform setup directory

```bash
cd edge-developer-kit-reference-scripts/platforms/coreultra/arl
```

### 4. Run the Setup Script

This step will configure the basic setup of the platform. Make sure all of the requirements have been met before proceeding to the next step.

```bash
sudo ./setup.sh
```
During the installation,you may be required to reboot your system. Reboot the system and run `./setup.sh` again. Installation is completed when you see this message:
> ✓ Platform configured

## Next Step
1. [Intel® Distribution of OpenVINO™ Toolkit](./usecases/openvino/README.md)

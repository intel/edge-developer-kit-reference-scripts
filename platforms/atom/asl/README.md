# Intel Atom® Processor X Series (Products formerly known as Amston Lake)

## Requirements

#### Validated Hardware
- AAEON RS-UPN-ASLX7835RE-A10-16128

## Quick Start

### 1. Install the Operating System

Install the latest [Ubuntu* 22.04 LTS Desktop](https://releases.ubuntu.com/jammy/). Refer to the [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop) if needed.

### 2. Download Scripts

This step will download all reference scripts from the repository.

```bash
git clone https://github.com/intel/edge-developer-kit-reference-scripts
```

### 3. Go to the Specific Setup Directory

This step will redirect user to the current platform setup directory

```bash
cd edge-developer-kit-reference-scripts/platforms/atom/asl
```

### 4. Run the Setup Script

This step will configure the basic setup of the platform. Make sure all of the requirements have been met before proceed to the next step.

```bash
./setup.sh
```

During the installation, it may ask you to reboot your system. Reboot the system and run `./setup.sh` again. Installation is completed when you see this message:

> ✓ Platform configured


## Next Steps

Refer to the available use cases and examples below

1. [OpenVINO™](https://docs.openvino.ai/)
2. [Intel® Edge Software Hub](https://www.intel.com/content/www/us/en/developer/topic-technology/edge-5g/edge-solutions/overview.html) 

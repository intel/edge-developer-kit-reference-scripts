# Intel® Core™ Processors (14th gen) (Products formerly Raptor Lake-P)

## Requirement
### Validated Hardware
- [Seavo Intel Rock Island Reference Design Board](https://www.seavo.com/en/products/products-info_itemid_482.html)

## Quick Start
### 1. Install operating system
Install latest [Ubuntu 22.04 LTS Desktop for Intel IoT platforms](https://ubuntu.com/download/iot/intel-iot). Refer to [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop#1-overview) if needed.

### 2. Download scripts
This step will download all reference scripts from the repository.
```
git clone https://github.com/intel/edge-developer-kit-reference-scripts
```

### 3. Go to specific setup directory
This step will redirect user to the current platform setup directory
```
cd edge-developer-kit-reference-scripts/platforms/core/rpl/rplp
```

### 4. Run setup script
This step will configure the basic setup of the platform. Make sure all of the requirements have been met before proceed with the step below.
```
./setup.sh
```
During installation, it may ask you to reboot your system. Reboot the system and run `./setup.sh` again. Installation is completed when you see this message:
> ✓ Platform configured

## Next Steps
Refer to available use cases and examples below
1. [OpenVINO](https://docs.openvino.ai/2023.3/home.html)
2. [Intel® Edge Software Hub](https://www.intel.com/content/www/us/en/developer/topic-technology/edge-5g/edge-solutions/overview.html)

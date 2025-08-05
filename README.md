# Edge Developer Kit Reference Scripts

This is a simplified developer kits reference setup scripts for various kind of Intel platforms and GPUs.

> **Note:** Main branch of this repository contains the latest development version of the project. It may include experimental features, work in progress, or unstable code.

## Recommended Edge Design Support

| Edge Design | Product Line | Product Name | Installer Support | Validated Hardware |
|-------------|--------------|--------------|-------------------|--------------------|
| **Scalable Graphics**| Arc B-series | B60 | ❌ Future Support | |
| | Arc B-series | B580 | ✅ Supported  | |
| | Arc A-Series | A770 | ✅ Supported  | |
| **Efficiency Optimized AI** | Core Ultra Processor Series 2 5/7/9 | Arrow Lake (ARL) | ✅ Supported | [Innodisk AXMB-D150 Arrow Island](https://www.innodisk.com/en/blog/intel-core-ultra-series2-reference-kit)<br>[IEI TANK-XM813](https://www.ieiworld.com/tw/product/model.php?II=1099)<br>[AAEON UP Xtreme ARL](https://up-board.org/up-xtreme-arl/)<br>[ASRock Industrial NUC BOX-255H](https://www.asrockind.com/en-gb/NUC%20BOX-255H) |
| | Core Ultra Processor 5/7/9 | Meteor Lake (MTL) | ✅ Supported | [Seavo* PIR-1014A AIoT Developer Kit](https://www.seavo.com/en/pir_devkit/)<br>[AAEON* UP Xtreme i14](https://up-board.org/up-xtreme-i14/)<br>[ASRock Industrial* NUC BOX-155H](https://www.asrockind.com/en-gb/NUC%20BOX-155H)<br>[Asus* NUC 14 Pro](https://www.asus.com/displays-desktops/nucs/nuc-mini-pcs/asus-nuc-14-pro/)
| **Mainstream** | Core Processors Series 2 |  Bartlett Lake (BTL) |  Future Support |
| | Core Processors Series |  Raptor Lake Refresh (RPL) | ✅ Supported | [IEI* TANK-XM811AI-RPL AIoT Developer Kit](https://www.ieiworld.com/en/product-ns/model.php?II=8)<br>[ASRock Industrial* iEPF-9030S-EW4](https://www.asrockind.com/iEPF-9030S-EW4) |
| **Entry** | Processor Series | Twin Lake (TWL) | ✅ Supported | AAEON RS-UPN-ADLN355-A10-0864 |

## Validated Hardware Matrix

**Below are the Validated Edge Design Combinations:**

| Edge Design | CPU Platform | GPU Configuration | Verification Date |
|-------------|--------------|-------------------|-------------------|
| **Efficiency Optimized AI** | **Arrow Lake (ARL)** | Arc B60 (dGPU) | ❌ Future Support |
| | | Arc B580 (dGPU) | ✅ July 2025 |
| | | Arc A770 (dGPU) | ✅ July 2025 |
| **Mainstream** |  Bartlett Lake (BTL) | Arc B60 | ❌ Future Support |

## Architecture Overview

```
edge-developer-kit-reference-scripts/
├── main_installer.sh              # Main entry point
├── platform_detection.sh          # Platform and hardware detection
├── npu_installer.sh               # NPU drivers (Core Ultra)
├── openvino_installer.sh          # OpenVINO and camera use cases
├── camera_installer.sh            # Camera drivers and tools
├── print_summary_table.sh         # Summarize post installation
└── usecases/                      # Reference implementation 
```

## System Requirements

- **OS**: Ubuntu 24.04 LTS only
- **Kernel**: Script will auto install HWE kernel
- **Privileges**: Must run with sudo/root
- **Internet**: Required for package downloads
- **Edge Design Platform**: All
- **GPU**: iGPU or/and dGPU of the setup

## Quick Start

1. **Install Operating System**
   Install the latest [Ubuntu* 24.04 LTS Desktop](https://releases.ubuntu.com/noble/). Refer to the [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop) if needed.

2. **Run Setup Script**

   This step will configure the basic setup of the platform. Ensure all of the requirements have been met before proceeding to the next step.

   ```bash
   git clone https://github.com/intel/edge-developer-kit-reference-scripts.git
   cd edge-developer-kit-reference-scripts
   sudo ./main_installer.sh
   ```
   After finished installation, it may ask you to reboot your system. Reboot the system.
   Installation is completed when you see this message:
   > ✓ Platform configured

   > System reboot is required.

3. **Re-run the Installer**
   ```bash
   sudo ./main_installer.sh
   ```
## Use Cases
1. [Intel® Distribution of OpenVINO™ Toolkit](usecases/ai/openvino/README.md)
2. [Open WebUI with Ollama](usecases/ai/openwebui-ollama/README.md)
3. [LLM RAG Toolkit](usecases/ai/rag-toolkit/README.md)
4. [AI Video Analytics](usecases/ai/ai-video-analytics/README.md)
5. [Digital Avatar](usecases/ai/digital-avatar/README.md)
6. [Time Coordinated Computing (TCC)](usecases/real-time/tcc_tutorial/README.md)
7. [Smart Parking](usecases/ai/smart-parking/README.md)
8. [Video Summarization & Visual RAG](usecases/ai/video_summarization)

## Troubleshooting

### Common Issues

**Wrong Kernel Version:**
```bash
✗ Unsupported kernel version: 6.8.x
This installer requires kernel 6.11.x
Please install HWE kernel: sudo apt install linux-generic-hwe-24.04
```

**Permission Error:**
```bash
✗ This script must be run with sudo or as root user
```

### Log Files
Installation logs are displayed in real-time. For troubleshooting, check:
- System package manager logs: `/var/log/apt/`
- Docker logs: `docker logs [container_name]`

- NPU logs: `/var/log/intel-npu.log`
- Installation logs: Terminal output

## Troubleshooting

### Platform Not Detected
- Check `/sys/class/dmi/id/product_name`
- Add to appropriate platform list

### NPU Not Available
- Verify Core Ultra platform
- Check if NPU device exists: `ls /dev/intel-npu*`
- May require system reboot

### GPU Issues
- Run standalone GPU installer: `../gpu/setup.sh`
- Check GPU detection: `lspci | grep -i vga`

## Support

For issues and questions:
- Check logs and error messages
- Verify platform compatibility
- Test individual components
- Report bugs with platform details in here https://github.com/intel/edge-developer-kit-reference-scripts/issues

## Disclaimer
This repository contains pre-production code and is intended for testing and evaluation purposes only. The code and features provided here are in development and may be incomplete, unstable, or subject to change without notice. Use this repository at your own risk.

The reference scripts provided in this repository have been validated and tested on the hardware listed in the documentation. While we strive to ensure compatibility and performance, these scripts may not function as expected on other hardware configurations. Users may encounter issues or unexpected behavior when running the scripts on untested hardware. If you encounter any issues or have suggestions for improvements, we welcome you to open an issue.

GStreamer* is an open source framework licensed under LGPL. See https://gstreamer.freedesktop.org/documentation/frequently-asked-questions/licensing.html. You are solely responsible for determining if your use of GStreamer requires any additional licenses.  Intel is not responsible for obtaining any such licenses, nor liable for any licensing fees due, in connection with your use of GStreamer.
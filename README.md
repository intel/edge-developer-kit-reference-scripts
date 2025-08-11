# Edge Developer Kit Reference Scripts

This repository provides simplified developer kit reference setup scripts for various Intel platforms and GPUs.

> **Note:** The main branch contains the latest development version of the project. It may include experimental features, work in progress, or unstable code.

## Table of Contents

- [Recommended Edge Design Support](#recommended-edge-design-support)
- [Architecture Overview](#architecture-overview)
- [System Requirements](#system-requirements)
- [Quick Start](#quick-start)
- [Use Cases](#use-cases)
- [Troubleshooting](#troubleshooting)
- [Support](#support)
- [Disclaimer](#disclaimer)

## Recommended Edge Design Support

| Product Collection | Code Name | Support | Validated Hardware |
|--------------|--------------|-------------------|--------------------|
| Intel® Arc™ Pro B-Series Graphics | Products formerly Battlemage | 📋 Planned | |
| Intel® Arc™ B-Series Graphics | Products formerly Battlemage | ✅ Supported  | |
| Intel® Arc™ A-Series Graphics | Products formerly Alchemist | ✅ Supported  | |
| Intel® Core™ Ultra Processors (Series 2) | Products formerly Arrow Lake | ✅ Supported | [Innodisk Intel® Core™ Ultra Series 2 Reference Kit](https://www.innodisk.com/en/blog/intel-core-ultra-series2-reference-kit)<br>[IEI TANK-XM813](https://www.ieiworld.com/tw/product/model.php?II=1099)<br>[AAEON UP Xtreme ARL](https://up-board.org/up-xtreme-arl/)<br>[ASRock Industrial NUC BOX-255H](https://www.asrockind.com/en-gb/NUC%20BOX-255H) |
| Intel® Core™ Ultra processors (Series 1) | Products formerly Meteor Lake | ✅ Supported | [Seavo* PIR-1014A AIoT Developer Kit](https://www.seavo.com/en/pir_devkit/)<br>[AAEON* UP Xtreme i14](https://up-board.org/up-xtreme-i14/)<br>[ASRock Industrial* NUC BOX-155H](https://www.asrockind.com/en-gb/NUC%20BOX-155H)<br>[Asus* NUC 14 Pro](https://www.asus.com/displays-desktops/nucs/nuc-mini-pcs/asus-nuc-14-pro/) |
| Intel® Core™ processors (Series 2) | Products formerly Bartlett Lake | 📋 Planned | |
| Intel® Core™ processors (Series 1) | Products formerly Raptor Lake | ✅ Supported | |
| Intel® Core™ Processor N-series | Products formerly Twin Lake | ✅ Supported | AAEON RS-UPN-ADLN355-A10-0864 |

## Architecture Overview

```
edge-developer-kit-reference-scripts/
├── main_installer.sh              # Main entry point
├── platform_detection.sh          # Platform and hardware detection
├── npu_installer.sh               # NPU drivers (Core Ultra)
├── gpu_installer.sh               # GPU drivers and tools
├── openvino_installer.sh          # OpenVINO and camera use cases
├── print_summary_table.sh         # Summarize post installation
└── usecases/                      # Reference implementation 
```

## System Requirements

- **Operating System:** Ubuntu 24.04 LTS (Desktop)
- **Kernel:** HWE kernel (auto-installed by script)
- **User Privileges:** Requires sudo/root access
- **Internet Connection:** Needed for package installation
- **Graphics:** Integrated (iGPU) and/or discrete (dGPU) GPU


## Quick Start

1. **Install Operating System**
   Install the latest [Ubuntu* 24.04 LTS Desktop](https://releases.ubuntu.com/noble/). Refer to the [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop) if needed.

2. **Run Setup Script**

   This step will configure the basic setup of the platform. Ensure all requirements have been met before proceeding.

   ```bash
   sudo bash -c "$(wget -qLO - https://raw.githubusercontent.com/intel/edge-developer-kit-reference-scripts/refs/heads/main/main_installer.sh)"
   ```



   During the installation process, you may be asked to reboot your system. Reboot when prompted.
   Installation is completed when you see this message:

   ```
   ========================================================================
   Running Installation Summary

   ==================== System Installation Summary ====================
   Item                      | Value
   ------------------------ -+-----------------------------------------
   Kernel Version            | 6.14.0-27-generic
   HWE Stack                 | Installed
   Ubuntu Version            | Ubuntu 24.04.3 LTS
   NPU Status                | Detected
   NPU Package               | intel-level-zero-npu
   NPU Version               | 1.19.0.20250707-16111289554
   intel-driver-compiler-npu | 1.19.0.20250707-16111289554
   intel-fw-npu              | 1.19.0.20250707-16111289554
   intel-level-zero-npu      | 1.19.0.20250707-16111289554
   level-zero                | 1.22.4
   GPU Type                  | Intel
   GPU Count                 | 4 Intel graphics device(s) detected
   GPU Driver                | i915 (loaded)
   GPU Device 1              | 00:02.0 VGA compatible controller: Intel Corporation Arrow Lake-U [Intel Graphics] (rev 06)
   GPU Device 2              | 03:00.0 VGA compatible controller: Intel Corporation Device e20b
   GPU Device 3              | 08:00.0 VGA compatible controller: Intel Corporation Device e20b
   GPU Device 4              | 80:14.5 Non-VGA unclassified device: Intel Corporation Device 7f2f (rev 10)
   ------------------------ -+-----------------------------------------
   Intel Graphics Packages   |
   ------------------------ -+-----------------------------------------
   i965-va-driver:amd64      | 2.4.1+dfsg1-1build2
   intel-gsc                 | 0.9.5-0ubuntu1~24.04~ppa1
   intel-media-va-driver-non-free:amd64 | 25.3.1-0ubuntu1~24.04~ppa1
   intel-opencl-icd          | 25.27.34303.9-1~24.04~ppa1
   libegl-mesa0:amd64        | 25.0.7-0ubuntu0.24.04.1
   ------------------------ -+-----------------------------------------
   Platform Status           | [✓] Platform is configured
   =====================================================================

   ========================================================================
   Installation completed: 2025-08-11 10:11:54
   Log file saved: /var/log/intel-platform-installer.log
   ========================================================================
   ```

## Use Cases

1. [Intel® Distribution of OpenVINO™ Toolkit](usecases/ai/openvino/README.md)
2. [Open WebUI with Ollama](usecases/ai/openwebui-ollama/README.md)
3. [LLM RAG Toolkit](usecases/ai/rag-toolkit/README.md)
4. [AI Video Analytics](usecases/ai/ai-video-analytics/README.md)
5. [Digital Avatar](usecases/ai/digital-avatar/README.md)
6. [Time Coordinated Computing (TCC)](usecases/real-time/tcc_tutorial/README.md)
7. [Smart Parking](usecases/ai/smart-parking/README.md)
8. [Video Summarization & Visual RAG](usecases/ai/video_summarization/README.md)

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

### Platform-Specific Issues

**Platform Not Detected:**
- Check `/sys/class/dmi/id/product_name`
- Add to appropriate platform list

**NPU Not Detected:**
- Confirm you are using a Core Ultra platform
- Check for NPU device: `ls /dev/intel-npu*`
- If missing, reboot the system and rerun the installer

**GPU Issues:**
- Run the GPU installer separately: `./gpu_installer.sh`
- Verify GPU detection: `lspci | grep -i vga`
- If issues persist, check for error messages in the terminal and review relevant log files
- Reboot the system after driver installation if prompted

### Log Files & Troubleshooting Steps

During installation, logs are displayed in real time. For deeper troubleshooting, consult these sources:

- **APT Package Logs:** `/var/log/apt/`
- **Docker Logs:** `docker logs [container_name]`
- **NPU Driver Logs:** `/var/log/intel-npu.log`
- **Installer Output:** Review terminal messages for errors or warnings

**Troubleshooting Checklist:**
- Review relevant log files for error details
- Confirm your hardware matches the supported platforms
- Test individual installer scripts (e.g., `gpu_installer.sh`, `npu_installer.sh`)
- Search for known issues in [GitHub Issues](https://github.com/intel/edge-developer-kit-reference-scripts/issues)
- When reporting a bug, include platform model, OS version, and log excerpts

For further assistance, open an issue on GitHub with detailed information.

## Disclaimer

This repository contains pre-production code and is intended for testing and evaluation purposes only. The code and features provided here are in development and may be incomplete, unstable, or subject to change without notice. Use this repository at your own risk.

The reference scripts provided in this repository have been validated and tested on the hardware listed in the documentation. While we strive to ensure compatibility and performance, these scripts may not function as expected on other hardware configurations. Users may encounter issues or unexpected behavior when running the scripts on untested hardware. If you encounter any issues or have suggestions for improvements, we welcome you to open an issue.

**GStreamer License Notice:** GStreamer* is an open source framework licensed under LGPL. See https://gstreamer.freedesktop.org/documentation/frequently-asked-questions/licensing.html. You are solely responsible for determining if your use of GStreamer requires any additional licenses. Intel is not responsible for obtaining any such licenses, nor liable for any licensing fees due, in connection with your use of GStreamer.
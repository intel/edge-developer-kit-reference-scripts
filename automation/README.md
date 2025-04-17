# E2E Devkit Automation

This section consists of scripts for devkit automation via GIO tool and STAR flashing.

## Devkit caller script
`devkit_auto.py` 
- BKC setup caller script

`devkit_auto_openvino.py`
- OpenVINO use case setup caller script

## Custom Ubuntu OS image creation
Folder [OS](/automation/OS)
- Ubuntu 24 Refer to [README](/automation/OS/Ubuntu24/README.md)

## Post PXE Flash
`post_install.sh` this script is for post PXE Ubuntu OS flashing. This script need to upload into artifactory https://af01p-png.devtools.intel.com/ui/repos/tree/General/devkit_auto-png-local

It consist of :
- Resize disk partition
    - Custom Ubuntu OS image in [OS](/automation/OS/) for PXE boot is only 30G. Need to resize `/` partition to use the rest unallocated space in devkit system.
- Add `user` into docker group and add `user` docker proxy


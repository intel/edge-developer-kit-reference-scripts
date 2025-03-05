#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# Exit on error and pipeline failure, enable error tracing
set -euo pipefail
trap 'echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit 1' ERR

# Color codes
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
MAGENTA="\e[35m"
CYAN="\e[36m"
NC="\e[0m"  # No color

# Print welcome banner
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║             V I S I O N   E D G E   A I                  ║
║                                                          ║
║----------------------------------------------------------║
║                                                          ║
║             Platform Installation Tool                   ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF

echo -e "\n${CYAN}This installation process requires multiple steps and may need several reboots.${NC}"
echo -e "${CYAN}After each reboot, please run this script again:${NC}\n"
echo -e "    ${YELLOW}$ make install_prerequisites ${NC}\n"
echo -e "${CYAN}The script will automatically track progress and continue from where it left off.${NC}"
echo -e "${CYAN}Installation will be complete when all components are marked with a ${GREEN}✓${CYAN}.${NC}\n"
echo -e "${MAGENTA}Press Enter to begin installation...${NC}"
read -r

# Ensure script is executed from the correct directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Progress file to track completed installations
PROGRESS_FILE="${SCRIPT_DIR}/.install_progress"

# Installation steps in order
INSTALL_STEPS=(
    "install_kernel.sh"
    "install_gpu_drivers.sh"
    "install_npu_drivers.sh"
    "install_docker.sh"
)

# Create progress file if it doesn't exist
if [[ ! -f "${PROGRESS_FILE}" ]]; then
    touch "${PROGRESS_FILE}"
fi

# Function to check if a step is completed
is_step_completed() {
    local step="$1"
    grep -q "^${step}$" "${PROGRESS_FILE}"
}

# Function to mark a step as completed
mark_step_completed() {
    local step="$1"
    echo "${step}" >> "${PROGRESS_FILE}"
}

# Function to check if reboot is pending
is_reboot_pending() {
    [[ -f /var/run/reboot-required ]]
}

# Function to set up auto-resume after reboot
setup_auto_resume() {
    local RESUME_CMD="cd \"${SCRIPT_DIR}\" && ./install.sh"
    if ! crontab -l 2>/dev/null | grep -q "${RESUME_CMD}"; then
        (crontab -l 2>/dev/null; echo "@reboot ${RESUME_CMD}") | crontab -
    fi
}

# Function to clean up auto-resume
cleanup_auto_resume() {
    if crontab -l 2>/dev/null | grep -q "${SCRIPT_DIR}/install.sh"; then
        crontab -l 2>/dev/null | grep -v "${SCRIPT_DIR}/install.sh" | crontab -
    fi
}

# Print progress banner
echo -e "\n${YELLOW}=== Installation Progress ===${NC}"
for step in "${INSTALL_STEPS[@]}"; do
    if is_step_completed "${step}"; then
        echo -e "${GREEN}✓ ${step}${NC}"
    else
        echo -e "${RED}○ ${step}${NC}"
    fi
done

# Execute remaining installation steps
for script in "${INSTALL_STEPS[@]}"; do
    if ! is_step_completed "${script}"; then
        echo -e "${YELLOW}Executing ${script}...${NC}"
        
        # Verify script exists and is executable
        if [[ ! -f "${script}" ]]; then
            echo -e "${RED}Error: ${script} not found${NC}"
            exit 1
        fi
        
        if [[ ! -x "${script}" ]]; then
            echo -e "${RED}Error: ${script} is not executable${NC}"
            exit 1
        fi
        
        # Set up auto-resume before running the script
        setup_auto_resume
        
        # Run the script with error handling
        if ! "./${script}"; then
            echo -e "${RED}Error: ${script} failed with exit code $?${NC}"
            exit 1
        fi
        
        # Check if reboot is required
        if is_reboot_pending; then
            echo -e "\n${RED}A system reboot is required to continue the installation.${NC}"
            echo -e "${YELLOW}The installation will automatically continue after reboot.${NC}"
            mark_step_completed "${script}"
            sudo reboot
            exit 0
        fi
        
        # Mark step as completed if no reboot was required
        mark_step_completed "${script}"
    fi
done

# All steps completed
if [[ -f "${PROGRESS_FILE}" ]]; then
    COMPLETED_STEPS=$(wc -l < "${PROGRESS_FILE}")
    TOTAL_STEPS=${#INSTALL_STEPS[@]}
    
    if [[ "${COMPLETED_STEPS}" -eq "${TOTAL_STEPS}" ]]; then
        echo -e "\n${GREEN}All installations completed successfully!${NC}"
        
        # Clean up
        cleanup_auto_resume
        rm -f "${PROGRESS_FILE}"
        
        # Final reboot recommendation
        echo -e "\n${YELLOW}It is recommended to perform a final system reboot.${NC}"
        read -rp "Would you like to reboot now? (y/N) " -n 1 REPLY
        echo
        if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
            sudo reboot
        fi
    fi
fi

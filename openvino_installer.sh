#!/bin/bash

# OpenVINO Installer with Virtual Environment
# Installs OpenVINO toolkit using pip in virtual environment
# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# OpenVINO Version Information
OPENVINO_VERSION="2025.2.0"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Status indicators
S_ERROR="❌"
S_VALID="✅"

# OpenVINO installation function
install_openvino_complete() {
    echo -e "${BLUE} Installing OpenVINO toolkit ${OPENVINO_VERSION}...${NC}"
    
    # Check OpenVINO dependencies for Ubuntu 24
    if ! check_openvino_dependencies; then
        echo -e "${RED}$S_ERROR OpenVINO dependency check failed${NC}"
        return 1
    fi
    
    # Install OpenVINO dependencies
    if ! install_openvino_dependencies; then
        echo -e "${RED}$S_ERROR OpenVINO dependency installation failed${NC}"
        return 1
    fi
    
    # Install OpenVINO in virtual environment
    if ! install_openvino_venv; then
        echo -e "${RED}$S_ERROR OpenVINO virtual environment installation failed${NC}"
        return 1
    fi
    
    # Set up OpenVINO environment
    if ! setup_openvino_environment; then
        echo -e "${RED}$S_ERROR OpenVINO environment setup failed${NC}"
        return 1
    fi
    
    # Verify OpenVINO installation
    if ! verify_openvino_installation; then
        echo -e "${RED}$S_ERROR OpenVINO installation verification failed${NC}"
        return 1
    fi
    
    echo -e "${GREEN}$S_VALID OpenVINO installation completed successfully${NC}"
    return 0
}

# Check OpenVINO dependencies for Ubuntu 24
check_openvino_dependencies() {
    echo -e "${BLUE} Checking OpenVINO dependencies for Ubuntu 24...${NC}"
    
    local dependency_issues=()
    
    # Check Ubuntu version (must be 24.04)
    echo "Checking Ubuntu version..."
    if [ -f /etc/lsb-release ]; then
        UBUNTU_VERSION=$(grep "DISTRIB_RELEASE" /etc/lsb-release | cut -d'=' -f2)
        if [[ "$UBUNTU_VERSION" == "24.04" ]]; then
            echo -e "${GREEN}$S_VALID Ubuntu 24.04 detected${NC}"
        else
            echo -e "${RED}$S_ERROR Ubuntu $UBUNTU_VERSION detected, OpenVINO requires Ubuntu 24.04${NC}"
            dependency_issues+=("Ubuntu version: $UBUNTU_VERSION (requires 24.04)")
        fi
    else
        echo -e "${RED}$S_ERROR Cannot determine Ubuntu version${NC}"
        dependency_issues+=("Ubuntu version: Unknown (requires 24.04)")
    fi
    
    # Check GCC version (must be 13.2.0 or compatible)
    echo "Checking GCC version..."
    if command -v gcc &> /dev/null; then
        GCC_VERSION=$(gcc --version | head -n1 | grep -oP '\d+\.\d+\.\d+' | head -n1)
        GCC_MAJOR=$(echo "$GCC_VERSION" | cut -d'.' -f1)
        GCC_MINOR=$(echo "$GCC_VERSION" | cut -d'.' -f2)
        
        if [[ "$GCC_MAJOR" -eq 13 ]] && [[ "$GCC_MINOR" -ge 2 ]]; then
            echo -e "${GREEN}$S_VALID GCC $GCC_VERSION detected (compatible)${NC}"
        elif [[ "$GCC_MAJOR" -gt 13 ]]; then
            echo -e "${GREEN}$S_VALID GCC $GCC_VERSION detected (newer version)${NC}"
        else
            echo -e "${RED}$S_ERROR GCC $GCC_VERSION detected, OpenVINO requires GCC 13.2.0 or higher${NC}"
            dependency_issues+=("GCC version: $GCC_VERSION (requires 13.2.0+)")
        fi
    else
        echo -e "${RED}$S_ERROR GCC not found${NC}"
        dependency_issues+=("GCC: Not installed (requires 13.2.0+)")
    fi
    
    # Check Python version (must be 3.9-3.12)
    echo "Checking Python version..."
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | grep -oP '\d+\.\d+\.\d+')
        PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
        PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)
        
        if [[ "$PYTHON_MAJOR" -eq 3 ]] && [[ "$PYTHON_MINOR" -ge 9 ]] && [[ "$PYTHON_MINOR" -le 12 ]]; then
            echo -e "${GREEN}$S_VALID Python $PYTHON_VERSION detected (compatible)${NC}"
        else
            echo -e "${RED}$S_ERROR Python $PYTHON_VERSION detected, OpenVINO requires Python 3.9-3.12${NC}"
            dependency_issues+=("Python version: $PYTHON_VERSION (requires 3.9-3.12)")
        fi
    else
        echo -e "${RED}$S_ERROR Python3 not found${NC}"
        dependency_issues+=("Python3: Not installed (requires 3.9-3.12)")
    fi
    
    # Check CMake version (must be 3.13 or higher)
    echo "Checking CMake version..."
    if command -v cmake &> /dev/null; then
        CMAKE_VERSION=$(cmake --version | head -n1 | grep -oP '\d+\.\d+\.\d+')
        CMAKE_MAJOR=$(echo "$CMAKE_VERSION" | cut -d'.' -f1)
        CMAKE_MINOR=$(echo "$CMAKE_VERSION" | cut -d'.' -f2)

        if [[ "$CMAKE_MAJOR" -gt 3 ]] || { [[ "$CMAKE_MAJOR" -eq 3 ]] && [[ "$CMAKE_MINOR" -ge 13 ]]; }; then
            echo -e "${GREEN}$S_VALID CMake $CMAKE_VERSION detected (compatible)${NC}"
        else
            echo -e "${RED}$S_ERROR CMake $CMAKE_VERSION detected, OpenVINO requires CMake 3.13 or higher${NC}"
            dependency_issues+=("CMake version: $CMAKE_VERSION (requires 3.13+)")
        fi
    else
        echo -e "${YELLOW} CMake not found, will be installed${NC}"
        # CMake will be installed in dependencies, so this is just a warning
    fi
    
    # Check additional build dependencies
    echo "Checking additional build dependencies..."
    local missing_tools=()
    
    if ! command -v make &> /dev/null; then
        missing_tools+=("make")
    fi
    
    if ! command -v pkg-config &> /dev/null; then
        missing_tools+=("pkg-config")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${YELLOW} Missing build tools: ${missing_tools[*]} (will be installed)${NC}"
    else
        echo -e "${GREEN}$S_VALID Build tools available${NC}"
    fi
    
    # Summary of dependency check
    echo ""
    echo "=================================================="
    echo "OpenVINO Dependency Check Summary"
    echo "=================================================="
    
    if [ ${#dependency_issues[@]} -eq 0 ]; then
        echo -e "${GREEN}$S_VALID All OpenVINO dependencies satisfied${NC}"
        echo "  ✓ Ubuntu 24.04"
        echo "  ✓ GCC 13.2.0+"
        echo "  ✓ Python 3.9-3.12"
        echo "  ✓ CMake 3.13+"
        return 0
    else
        echo -e "${RED}$S_ERROR Dependency issues found:${NC}"
        for issue in "${dependency_issues[@]}"; do
            echo "  ✗ $issue"
        done
        echo ""
        echo -e "${YELLOW} Please resolve these issues before installing OpenVINO${NC}"
        echo "Installation will continue but may fail due to dependency issues."
        
        # Ask user if they want to continue
        read -p "Continue with installation despite dependency issues? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled by user"
            exit 1
        fi
    fi
}

# Install OpenVINO dependencies
install_openvino_dependencies() {
    echo -e "${BLUE} Installing OpenVINO dependencies for Ubuntu 24...${NC}"
    
    # Update package lists
    apt-get update
    
    # Core Python dependencies
    local python_deps=(
        "python3"
        "python3-pip"
        "python3-venv"
        "python3-dev"
        "python3-setuptools"
        "python3-wheel"
    )
    
    # Build dependencies
    local build_deps=(
        "build-essential"
        "gcc-13"
        "g++-13"
        "cmake"
        "make"
        "pkg-config"
        "libtool"
        "autoconf"
        "automake"
    )
    
    # System libraries
    local system_deps=(
        "wget"
        "curl"
        "git"
        "unzip"
        "software-properties-common"
        "ca-certificates"
        "gnupg"
        "lsb-release"
    )
    
    # OpenVINO specific dependencies
    local openvino_deps=(
        "libgtk-3-dev"
        "libavcodec-dev"
        "libavformat-dev"
        "libswscale-dev"
        "libgstreamer1.0-dev"
        "libgstreamer-plugins-base1.0-dev"
        "libpng-dev"
        "libjpeg-dev"
        "libopenexr-dev"
        "libtiff-dev"
        "libwebp-dev"
        "libopenblas-dev"
        "liblapack-dev"
        "libhdf5-dev"
        "ocl-icd-opencl-dev"
        "opencl-headers"
        "libva-dev"
        "vainfo"
    )
    
    echo "Installing Python dependencies..."
    apt-get install -y "${python_deps[@]}"
    
    echo "Installing build dependencies..."
    apt-get install -y "${build_deps[@]}"
    
    echo "Installing system dependencies..."
    apt-get install -y "${system_deps[@]}"
    
    echo "Installing OpenVINO specific dependencies..."
    apt-get install -y "${openvino_deps[@]}"
    
    # Ensure GCC 13 is the default
    echo "Configuring GCC 13 as default..."
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 100
    
    # Verify CMake version after installation
    if command -v cmake &> /dev/null; then
        CMAKE_VERSION=$(cmake --version | head -n1 | grep -oP '\d+\.\d+\.\d+')
        echo -e "${GREEN}$S_VALID CMake $CMAKE_VERSION installed${NC}"
    fi
    
    # Verify Python version
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | grep -oP '\d+\.\d+\.\d+')
        echo -e "${GREEN}$S_VALID Python $PYTHON_VERSION available${NC}"
    fi
    
    # Verify GCC version
    if command -v gcc &> /dev/null; then
        GCC_VERSION=$(gcc --version | head -n1 | grep -oP '\d+\.\d+\.\d+' | head -n1)
        echo -e "${GREEN}$S_VALID GCC $GCC_VERSION configured${NC}"
    fi
    
    echo -e "${GREEN}$S_VALID OpenVINO dependencies installed and configured${NC}"
}

# Install OpenVINO in virtual environment
install_openvino_venv() {
    echo -e "${BLUE} Setting up OpenVINO virtual environment...${NC}"
    
    # Create OpenVINO directory
    mkdir -p /opt/intel
    cd /opt/intel || return 1
    
    # Step 1: Create virtual environment
    echo "Step 1: Creating virtual environment..."
    python3 -m venv openvino_env
    
    # Step 2: Activate virtual environment
    echo "Step 2: Activating virtual environment..."
    # shellcheck disable=SC1091
    source openvino_env/bin/activate
    
    # Step 3: Upgrade pip to latest version
    echo "Step 3: Upgrading pip..."
    python -m pip install --upgrade pip
    
    # Step 4: Download and install the package
    echo "Step 4: Installing OpenVINO ${OPENVINO_VERSION}..."
    pip install openvino==${OPENVINO_VERSION}
    
    # Install additional packages for development
    echo "Installing additional OpenVINO packages..."
    pip install "openvino-dev[pytorch,tensorflow2,onnx]" notebook jupyter
    
    deactivate
    
    echo -e "${GREEN}$S_VALID OpenVINO ${OPENVINO_VERSION} installed in virtual environment${NC}"
}

# Set up OpenVINO environment
setup_openvino_environment() {
    echo -e "${BLUE} Setting up OpenVINO environment...${NC}"
    
    # Create OpenVINO environment script
    cat > /opt/intel/openvino_env.sh << 'EOF'
#!/bin/bash
# OpenVINO Environment Setup for Virtual Environment

# Activate OpenVINO virtual environment
source /opt/intel/openvino_env/bin/activate

# Add OpenVINO environment variables
export INTEL_OPENVINO_DIR=/opt/intel/openvino_env
export OpenVINO_DIR=$INTEL_OPENVINO_DIR/lib/python*/site-packages/openvino

# NPU support (for Core Ultra)
export OPENVINO_NPU_DRIVER_PATH=/usr/lib/x86_64-linux-gnu/

echo "OpenVINO virtual environment activated"
echo "OpenVINO version: $(python -c 'import openvino; print(openvino.__version__)' 2>/dev/null || echo 'Not available')"
EOF
    
    chmod +x /opt/intel/openvino_env.sh
    
    # Create activation script for users
    cat > /opt/intel/activate_openvino.sh << 'EOF'
#!/bin/bash
# Quick OpenVINO Activation Script
echo "Activating OpenVINO virtual environment..."
source /opt/intel/openvino_env/bin/activate
echo "OpenVINO environment ready. Type 'deactivate' to exit."
EOF
    
    chmod +x /opt/intel/activate_openvino.sh
    
    # Add alias to bashrc for easy activation
    if ! grep -q "alias openvino=" /etc/bash.bashrc; then
        echo "# Intel OpenVINO Quick Activation" >> /etc/bash.bashrc
        echo "alias openvino='source /opt/intel/activate_openvino.sh'" >> /etc/bash.bashrc
    fi
    
    echo -e "${GREEN}$S_VALID OpenVINO environment configured${NC}"
    echo "  - Use 'openvino' command to activate OpenVINO environment"
    echo "  - Or run: source /opt/intel/openvino_env/bin/activate"
}

# Query OpenVINO detected devices
query_openvino_devices() {
    echo -e "${BLUE} Querying OpenVINO for detected devices...${NC}"
    
    cd /opt/intel || return 1
    
    # Create temporary device query script
    cat > temp_device_query.py << 'EOF'
#!/usr/bin/env python3
import openvino as ov

try:
    # Initialize OpenVINO Core
    core = ov.Core()
    
    # Get all available devices
    devices = core.available_devices
    print(f"Total devices detected: {len(devices)}")
    print("=" * 50)
    
    if not devices:
        print(" No devices detected")
        exit(1)
    
    # Check specific device types
    cpu_found = False
    gpu_found = []
    npu_found = False
    
    for device in devices:
        device_name = core.get_property(device, "FULL_DEVICE_NAME")
        
        print(f"Device: {device}")
        print(f"  Name: {device_name}")
        
        # Get device capabilities
        try:
            supported_props = core.get_property(device, "SUPPORTED_PROPERTIES")
            print(f"  Type: {device}")
            
            if device == "CPU":
                cpu_found = True
                print("  ✓ CPU device available")
            elif device.startswith("GPU"):
                gpu_found.append(device)
                print(f"  ✓ GPU device available: {device}")
            elif device == "NPU":
                npu_found = True
                print("  ✓ NPU device available")
            
        except Exception as e:
            print(f"  ⚠ Error getting device properties: {e}")
        
        print("-" * 30)
    
    # Summary
    print("\nDevice Summary:")
    print(f"CPU: {'✓ Available' if cpu_found else ' Not detected'}")
    if gpu_found:
        for gpu in gpu_found:
            print(f"GPU ({gpu}): ✓ Available")
    else:
        print("GPU:  Not detected")
    print(f"NPU: {'✓ Available' if npu_found else ' Not detected'}")
    
    # Platform recommendations
    print("\nPlatform Analysis:")
    if npu_found:
        print(" NPU detected - This appears to be a Core Ultra platform")
    if gpu_found:
        print(f" {len(gpu_found)} GPU(s) detected - Discrete graphics available")
    if cpu_found:
        print(" CPU device ready for inference")
    
except Exception as e:
    print(f"Error querying devices: {e}")
    exit(1)
EOF
    
    # Run device query in virtual environment
    # shellcheck disable=SC1091
    if source openvino_env/bin/activate && python temp_device_query.py && deactivate; then
        echo -e "${GREEN}$S_VALID Device query completed successfully${NC}"
    else
        echo -e "${RED}$S_ERROR Failed to query OpenVINO devices${NC}"
    fi
    
    # Clean up temporary script
    rm -f temp_device_query.py
}

# Verify final dependencies after installation
verify_final_dependencies() {
    echo -e "${BLUE} Performing final dependency verification...${NC}"
    
    local verification_passed=true
    
    # Re-check all critical dependencies
    echo "Final system verification:"
    
    # Ubuntu version
    if [ -f /etc/lsb-release ]; then
        UBUNTU_VERSION=$(grep "DISTRIB_RELEASE" /etc/lsb-release | cut -d'=' -f2)
        if [[ "$UBUNTU_VERSION" == "24.04" ]]; then
            echo -e "  ${GREEN}$S_VALID Ubuntu 24.04${NC}"
        else
            echo -e "  ${RED}$S_ERROR Ubuntu $UBUNTU_VERSION${NC}"
            verification_passed=false
        fi
    fi
    
    # GCC version
    if command -v gcc &> /dev/null; then
        GCC_VERSION=$(gcc --version | head -n1 | grep -oP '\d+\.\d+\.\d+' | head -n1)
        GCC_MAJOR=$(echo "$GCC_VERSION" | cut -d'.' -f1)
        GCC_MINOR=$(echo "$GCC_VERSION" | cut -d'.' -f2)
        
        if [[ "$GCC_MAJOR" -eq 13 ]] && [[ "$GCC_MINOR" -ge 2 ]] || [[ "$GCC_MAJOR" -gt 13 ]]; then
            echo -e "  ${GREEN}$S_VALID GCC $GCC_VERSION${NC}"
        else
            echo -e "  ${RED}$S_ERROR GCC $GCC_VERSION (requires 13.2.0+)${NC}"
            verification_passed=false
        fi
    else
        echo -e "  ${RED}$S_ERROR GCC not available${NC}"
        verification_passed=false
    fi
    
    # Python version in virtual environment
    cd /opt/intel || return 1
    # shellcheck disable=SC1091
    if source openvino_env/bin/activate; then
        PYTHON_VERSION=$(python --version | grep -oP '\d+\.\d+\.\d+')
        PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
        PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)
        
        if [[ "$PYTHON_MAJOR" -eq 3 ]] && [[ "$PYTHON_MINOR" -ge 9 ]] && [[ "$PYTHON_MINOR" -le 12 ]]; then
            echo -e "  ${GREEN}$S_VALID Python $PYTHON_VERSION (in venv)${NC}"
        else
            echo -e "  ${RED}$S_ERROR Python $PYTHON_VERSION (requires 3.9-3.12)${NC}"
            verification_passed=false
        fi
        deactivate
    else
        echo -e "  ${RED}$S_ERROR Python virtual environment not accessible${NC}"
        verification_passed=false
    fi
    
    # CMake version
    if command -v cmake &> /dev/null; then
        CMAKE_VERSION=$(cmake --version | head -n1 | grep -oP '\d+\.\d+\.\d+')
        CMAKE_MAJOR=$(echo "$CMAKE_VERSION" | cut -d'.' -f1)
        CMAKE_MINOR=$(echo "$CMAKE_VERSION" | cut -d'.' -f2)
        
        if [[ "$CMAKE_MAJOR" -gt 3 ]] || { [[ "$CMAKE_MAJOR" -eq 3 ]] && [[ "$CMAKE_MINOR" -ge 13 ]]; }; then
            echo -e "  ${GREEN}$S_VALID CMake $CMAKE_VERSION${NC}"
        else
            echo -e "  ${RED}$S_ERROR CMake $CMAKE_VERSION (requires 3.13+)${NC}"
            verification_passed=false
        fi
    else
        echo -e "  ${RED}$S_ERROR CMake not available${NC}"
        verification_passed=false
    fi
    
    # OpenVINO import test in virtual environment
    cd /opt/intel || return 1
    # shellcheck disable=SC1091
    if source openvino_env/bin/activate && python -c "import openvino as ov; print(f'OpenVINO {ov.__version__} imported successfully')" &>/dev/null && deactivate; then
        echo -e "  ${GREEN}$S_VALID OpenVINO import test passed${NC}"
    else
        echo -e "  ${RED}$S_ERROR OpenVINO import test failed${NC}"
        verification_passed=false
    fi
    
    # Final result
    if [ "$verification_passed" = true ]; then
        echo -e "${GREEN}$S_VALID All dependencies verified successfully${NC}"
        echo "OpenVINO installation meets all Ubuntu 24.04 requirements:"
        echo "  ✓ Ubuntu 24.04 LTS"
        echo "  ✓ GCC 13.2.0+"
        echo "  ✓ Python 3.9-3.12"
        echo "  ✓ CMake 3.13+"
        echo "  ✓ OpenVINO functional"
    else
        echo -e "${YELLOW} Some dependency verification checks failed${NC}"
        echo "OpenVINO may still function but optimal performance is not guaranteed"
    fi
}

# Verify OpenVINO installation
verify_openvino_installation() {
    echo -e "${BLUE} Verifying OpenVINO installation...${NC}"
    
    # Test OpenVINO in virtual environment
    echo "Testing OpenVINO virtual environment..."
    cd /opt/intel || return 1
    # shellcheck disable=SC1091
    if source openvino_env/bin/activate && python -c "import openvino as ov; print(f'✓ OpenVINO version: {ov.__version__}'); core = ov.Core(); print(f'✓ Available devices: {core.available_devices}')" && deactivate; then
        echo -e "${GREEN}$S_VALID OpenVINO virtual environment test successful${NC}"
    else
        echo -e "${YELLOW} OpenVINO virtual environment test failed${NC}"
    fi
    
    # Query detected devices (CPU, GPU.0, GPU.1, NPU)
    echo -e "${BLUE} Querying OpenVINO detected devices...${NC}"
    query_openvino_devices
    
    # Verify dependencies are still correct after installation
    echo -e "${BLUE} Final dependency verification...${NC}"
    verify_final_dependencies
    
    # Check if virtual environment exists
    if [ -d "/opt/intel/openvino_env" ]; then
        echo -e "${GREEN}$S_VALID OpenVINO virtual environment created${NC}"
    else
        echo -e "${RED}$S_ERROR OpenVINO virtual environment not found${NC}"
    fi
    
    # Check activation scripts
    if [ -f "/opt/intel/activate_openvino.sh" ]; then
        echo -e "${GREEN}$S_VALID OpenVINO activation script created${NC}"
    else
        echo -e "${YELLOW} OpenVINO activation script not found${NC}"
    fi
    
    # Create sample verification script
    create_openvino_test_script
}

# Create OpenVINO test script
create_openvino_test_script() {
    echo -e "${BLUE} Creating OpenVINO test script...${NC}"
    
    mkdir -p /opt/intel/openvino_tests
    
    cat > /opt/intel/openvino_tests/test_openvino.py << 'EOF'
#!/usr/bin/env python3
"""
OpenVINO Installation Test Script
Tests basic OpenVINO functionality and comprehensive device detection
"""

import sys
try:
    import openvino as ov
    import numpy as np
    print(f"✓ OpenVINO version: {ov.__version__}")
    
    # Initialize OpenVINO Core
    core = ov.Core()
    devices = core.available_devices
    print(f"✓ Total devices detected: {len(devices)}")
    print("=" * 60)
    
    # Detailed device analysis
    cpu_found = False
    gpu_devices = []
    npu_found = False
    
    for device in devices:
        try:
            device_name = core.get_property(device, "FULL_DEVICE_NAME")
            print(f"Device: {device}")
            print(f"  Full Name: {device_name}")
            
            # Categorize devices
            if device == "CPU":
                cpu_found = True
                print("  ✓ CPU device available for inference")
            elif device.startswith("GPU"):
                gpu_devices.append(device)
                print(f"  ✓ GPU device available: {device}")
                # Try to get GPU-specific info
                try:
                    device_type = core.get_property(device, "DEVICE_TYPE")
                    print(f"  GPU Type: {device_type}")
                except:
                    pass
            elif device == "NPU":
                npu_found = True
                print("  ✓ NPU device available (Core Ultra)")
            else:
                print(f"  ℹ Other device: {device}")
            
        except Exception as e:
            print(f"   Error querying device {device}: {e}")
        
        print("-" * 40)
    
    # Summary report
    print("\n" + "=" * 60)
    print("DEVICE DETECTION SUMMARY")
    print("=" * 60)
    print(f"CPU: {'✓ DETECTED' if cpu_found else ' NOT DETECTED'}")
    
    if gpu_devices:
        for i, gpu in enumerate(gpu_devices):
            print(f"GPU.{i}: ✓ DETECTED ({gpu})")
    else:
        print("GPU:  NOT DETECTED")
    
    print(f"NPU: {'✓ DETECTED' if npu_found else ' NOT DETECTED'}")
    
    # Platform analysis
    print("\n" + "=" * 60)
    print("PLATFORM ANALYSIS")
    print("=" * 60)
    
    if npu_found:
        print(" Intel Core Ultra platform detected (NPU available)")
    if len(gpu_devices) > 1:
        print(f" Multi-GPU system detected ({len(gpu_devices)} GPUs)")
    elif len(gpu_devices) == 1:
        print(" Single GPU system detected")
    if cpu_found:
        print(" CPU inference ready")
    
    total_devices = len([d for d in [cpu_found, bool(gpu_devices), npu_found] if d])
    print(f"\n✓ Total usable device types: {total_devices}")
    print("✓ OpenVINO device detection test completed successfully")
    
except ImportError as e:
    print(f"✗ Failed to import OpenVINO: {e}")
    sys.exit(1)
except Exception as e:
    print(f"✗ OpenVINO device detection test failed: {e}")
    sys.exit(1)
EOF

    chmod +x /opt/intel/openvino_tests/test_openvino.py
    
    # Create virtual environment test script
    cat > /opt/intel/openvino_tests/test_openvino_venv.sh << 'EOF'
#!/bin/bash
# Test OpenVINO in virtual environment

echo "Testing OpenVINO in virtual environment..."
cd /opt/intel
source openvino_env/bin/activate
python openvino_tests/test_openvino.py
deactivate
echo "Virtual environment test completed"
EOF

    chmod +x /opt/intel/openvino_tests/test_openvino_venv.sh
    
    # Create dedicated device query script
    cat > /opt/intel/openvino_tests/query_devices.py << 'EOF'
#!/usr/bin/env python3
"""
OpenVINO Device Query Script
Comprehensive device detection and analysis for OpenVINO
"""

import openvino as ov
import sys

def main():
    print("=" * 70)
    print("OpenVINO Device Detection and Analysis")
    print("=" * 70)
    
    try:
        # Initialize OpenVINO Core
        core = ov.Core()
        devices = core.available_devices
        
        if not devices:
            print(" No OpenVINO devices detected!")
            return False
        
        print(f" Total devices found: {len(devices)}")
        print()
        
        # Device categories
        cpu_devices = []
        gpu_devices = []
        npu_devices = []
        other_devices = []
        
        # Analyze each device
        for device in devices:
            try:
                device_name = core.get_property(device, "FULL_DEVICE_NAME")
                
                print(f" Device: {device}")
                print(f"   Name: {device_name}")
                
                # Get additional properties if available
                try:
                    device_type = core.get_property(device, "DEVICE_TYPE")
                    print(f"   Type: {device_type}")
                except:
                    pass
                
                # Categorize device
                if device == "CPU":
                    cpu_devices.append((device, device_name))
                    print("   Category: CPU Processor")
                elif device.startswith("GPU"):
                    gpu_devices.append((device, device_name))
                    print(f"   Category: Graphics Processor ({device})")
                elif device == "NPU":
                    npu_devices.append((device, device_name))
                    print("   Category: Neural Processing Unit")
                else:
                    other_devices.append((device, device_name))
                    print(f"   Category: Other ({device})")
                
                print()
                
            except Exception as e:
                print(f"    Error querying device: {e}")
                print()
        
        # Summary table
        print("=" * 70)
        print("DEVICE SUMMARY")
        print("=" * 70)
        
        print(f"CPU Devices: {len(cpu_devices)}")
        for device, name in cpu_devices:
            print(f"   {device}: {name}")
        
        print(f"\nGPU Devices: {len(gpu_devices)}")
        for device, name in gpu_devices:
            print(f"   {device}: {name}")
        
        print(f"\nNPU Devices: {len(npu_devices)}")
        for device, name in npu_devices:
            print(f"   {device}: {name}")
        
        if other_devices:
            print(f"\nOther Devices: {len(other_devices)}")
            for device, name in other_devices:
                print(f"  ℹ {device}: {name}")
        
        # Platform analysis
        print("\n" + "=" * 70)
        print("PLATFORM ANALYSIS")
        print("=" * 70)
        
        if npu_devices:
            print(" Intel Core Ultra platform detected")
            print("   - NPU acceleration available for AI workloads")
        
        if len(gpu_devices) > 1:
            print(f" Multi-GPU configuration detected ({len(gpu_devices)} GPUs)")
            print("   - Multiple GPU acceleration available")
        elif len(gpu_devices) == 1:
            print(" Single GPU configuration detected")
            print("   - GPU acceleration available")
        
        if cpu_devices:
            print(" CPU inference ready")
            print("   - CPU-based inference available")
        
        total_compute_devices = len(cpu_devices) + len(gpu_devices) + len(npu_devices)
        print(f"\n Total compute devices available: {total_compute_devices}")
        
        return True
        
    except Exception as e:
        print(f" Error during device detection: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
EOF
    
    chmod +x /opt/intel/openvino_tests/query_devices.py
    
    # Create wrapper script for device query
    cat > /opt/intel/openvino_tests/query_devices.sh << 'EOF'
#!/bin/bash
# Query OpenVINO devices in virtual environment

echo "Querying OpenVINO devices..."
cd /opt/intel
source openvino_env/bin/activate
python openvino_tests/query_devices.py
deactivate
EOF
    
    chmod +x /opt/intel/openvino_tests/query_devices.sh
    
    echo -e "${GREEN}$S_VALID OpenVINO test scripts created in /opt/intel/openvino_tests/${NC}"
    echo "  - test_openvino.py: Comprehensive OpenVINO device test"
    echo "  - test_openvino_venv.sh: Virtual environment OpenVINO test"
    echo "  - query_devices.py: Detailed device detection script"
    echo "  - query_devices.sh: Device query wrapper script"
    echo ""
    echo "To query detected devices (CPU, GPU.0, GPU.1, NPU):"
    echo "  • Run: /opt/intel/openvino_tests/query_devices.sh"
    echo "  • Or manually: source /opt/intel/openvino_env/bin/activate && python /opt/intel/openvino_tests/query_devices.py"
}

# Standalone dependency check function (can be called independently)
check_system_compatibility() {
    echo "======================================================================"
    echo "OpenVINO System Compatibility Check"
    echo "======================================================================"
    
    check_openvino_dependencies
    
    echo ""
    echo "To install OpenVINO with these dependencies, run:"
    echo "  sudo bash openvino_installer.sh"
    echo "  Or call: install_openvino_complete"
}

# Main execution - only run if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo "$S_ERROR This script must be run with sudo or as root user"
        exit 1
    fi
    
    # Run complete OpenVINO installation
    install_openvino_complete
fi

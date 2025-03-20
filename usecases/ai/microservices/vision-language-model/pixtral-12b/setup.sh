#!/bin/bash
# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# Exit immediately if a command exits with a non-zero status
set -e

# Function to create and activate a virtual environment
create_and_activate_venv() {
    echo "Creating a virtual environment..."
    python3 -m venv --system-site-packages .venv
    echo "Activating the virtual environment..."
    # shellcheck source=/dev/null
    source .venv/bin/activate
}

# Function to upgrade pip and install dependencies
install_dependencies() {
    echo "Upgrading pip..."
    pip install --upgrade pip
    echo "Installing dependencies..."
    pip install -r requirements.txt
}

# Function to run the server
run_server() {
    echo "Starting the server..."
    python backend/server.py
}

# Main script execution
create_and_activate_venv
install_dependencies
run_server

# Deactivate the virtual environment (optional)
echo "Setup and server execution complete."

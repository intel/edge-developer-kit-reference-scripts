#!/bin/bash
# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# Exit immediately if a command exits with a non-zero status
set -e

# Create a virtual environment
echo "Creating a virtual environment..."
python3 -m venv .venv

# Activate the virtual environment
echo "Activating the virtual environment..."
# shellcheck source=/dev/null
source .venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install dependencies from requirements.txt
echo "Installing dependencies..."
pip install -r requirements.txt

# Run server.py
echo "Starting the server..."
python backend/server.py

# Deactivate the virtual environment (optional)
echo "Setup and server execution complete."

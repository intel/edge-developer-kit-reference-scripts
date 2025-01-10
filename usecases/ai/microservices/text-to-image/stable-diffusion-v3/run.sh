#!/bin/bash
# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# Exit immediately if a command exits with a non-zero status
set -e

# Activate the virtual environment
echo "Activating the virtual environment..."
# shellcheck source=/dev/null
source .venv/bin/activate

# Run server.py
echo "Starting the server..."
python backend/client.py

# Deactivate the virtual environment
echo "Deactivating the virtual environment..."
deactivate

# Inform completion
echo "Setup and server execution complete."

#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_URL="https://github.com/xinntao/Real-ESRGAN"
TEMP_DIR="$SCRIPT_DIR/temp"
OVERWRITE_DIR="$SCRIPT_DIR/overwrite"

# Clone the repository into a temporary folder
if [ ! -d "$SCRIPT_DIR/.git" ]; then
    echo "Cloning repository into the temporary folder: $TEMP_DIR..."
    mkdir -p "$TEMP_DIR"
    if git clone "$REPO_URL" "$TEMP_DIR"; then
        echo "Repository cloned successfully into $TEMP_DIR."

        # Check and remove .gitignore if it exists in TEMP_DIR
        if [ -f "$TEMP_DIR/.gitignore" ]; then
            echo ".gitignore file found in $TEMP_DIR. Removing it..."
            rm "$TEMP_DIR/.gitignore"
            echo ".gitignore file removed."
        fi

        echo "Moving repository contents to the current directory..."
        mv "$TEMP_DIR"/* "$TEMP_DIR"/.git* "$SCRIPT_DIR"
        rm -rf "$TEMP_DIR"
        echo "Repository contents moved to the current directory."

        # Overwrite current files with files from the overwrite folder
        if [ -d "$OVERWRITE_DIR" ]; then
            echo "Overwriting files from $OVERWRITE_DIR to the current directory..."
            find "$OVERWRITE_DIR" -type f | while read -r file; do
                relative_path="${file#"$OVERWRITE_DIR"/}"
                target_file="$SCRIPT_DIR/$relative_path"
                target_dir=$(dirname "$target_file")

                # Create target directory if it doesn't exist
                if [ ! -d "$target_dir" ]; then
                    mkdir -p "$target_dir"
                fi

                # Copy the file
                cp "$file" "$target_file"
                echo "Overwritten: $target_file"
            done
            echo "All files from $OVERWRITE_DIR have been successfully copied to the current directory."
        else
            echo "Overwrite directory $OVERWRITE_DIR does not exist. Skipping overwrite."
        fi
    else
        echo "Error: Failed to clone repository." >&2
        rm -rf "$TEMP_DIR"
        exit 1
    fi
else
    echo "Git repository already initialized in the current directory. Skipping clone."
fi
#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

REPO_URL="https://github.com/OpenTalker/SadTalker.git"
FOLDER_DIR="SadTalker"
OVERWRITE_DIR="overwrite"

# Clone the repository into a folder
if [ ! -d ".git" ]; then
    if [ -d "$FOLDER_DIR" ]; then
        echo "Error: Directory $FOLDER_DIR already exists. Please remove it or choose a different folder name." >&2
        exit 1
    fi

    echo "Cloning repository into $FOLDER_DIR"
    if git clone "$REPO_URL" "$FOLDER_DIR"; then
        echo "Repository cloned successfully into $FOLDER_DIR."

        # Overwrite current files with files from the overwrite folder
        if [ -d "$OVERWRITE_DIR" ]; then
            echo "Overwriting files from $OVERWRITE_DIR to $FOLDER_DIR..."
            find "$OVERWRITE_DIR" -type f | while read -r file; do
                relative_path="${file#"$OVERWRITE_DIR"/}"
                target_file="$FOLDER_DIR/$relative_path"
                target_dir=$(dirname "$target_file")

                # Create target directory if it doesn't exist
                if [ ! -d "$target_dir" ]; then
                    mkdir -p "$target_dir" || {
                        echo "Error: Failed to create directory $target_dir" >&2
                        exit 1
                    }
                fi

                # Copy the file
                cp "$file" "$target_file" || {
                    echo "Error: Failed to copy $file to $target_file" >&2
                    exit 1
                }
                echo "Overwritten: $target_file"
            done
            echo "All files from $OVERWRITE_DIR have been successfully copied to $FOLDER_DIR."
        else
            echo "Overwrite directory $OVERWRITE_DIR does not exist. Skipping overwrite."
        fi
    else
        echo "Error: Failed to clone repository." >&2
        exit 1
    fi
else
    echo "Git repository already initialized in the current directory. Skipping clone."
fi
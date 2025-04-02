#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

REPO_URL="https://github.com/sammysun0711/openvino_aigc_samples.git"
WAV2LIP_DIR="Wav2Lip"
FOLDER_DIR="aigc_samples"
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

        # Move the FOLDER_DIR/WAV2LIP_DIR to wav2lip folder delete others
        if [ -d "$FOLDER_DIR/$WAV2LIP_DIR" ]; then
            echo "Moving $FOLDER_DIR/$WAV2LIP_DIR to wav2lip folder..."
            mv "$FOLDER_DIR/$WAV2LIP_DIR" "wav2lip" || {
                echo "Error: Failed to move $FOLDER_DIR/$WAV2LIP_DIR to wav2lip" >&2
                exit 1
            }
            echo "Successfully moved $FOLDER_DIR/$WAV2LIP_DIR to wav2lip."

            echo "Deleting all other contents in $FOLDER_DIR..."
            rm -rf "$FOLDER_DIR" || {
                echo "Error: Failed to delete $FOLDER_DIR" >&2
                exit 1
            }
            echo "All other contents in $FOLDER_DIR have been deleted."
            FOLDER_DIR="wav2lip"
        else
            echo "Error: $FOLDER_DIR/$WAV2LIP_DIR does not exist. Cannot proceed." >&2
            exit 1
        fi


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
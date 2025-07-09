#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

REPO_URL="https://github.com/KwaiVGI/LivePortrait.git"
TARGET_PATH="liveportrait"
OVERWRITE_DIR="overwrite"
XPU_OVERWRITE_FOLDER="intel_xpu"

# Clone the repository into the specified relative path
if [ ! -d "$TARGET_PATH" ]; then
    echo "Cloning repository into $TARGET_PATH..."
    if git clone --depth 1 --single-branch "$REPO_URL" "$TARGET_PATH"; then
        echo "Repository cloned successfully."
    else
        echo "Error: Failed to clone repository." >&2
        exit 1
    fi
else
    echo "Directory $TARGET_PATH already exists. Skipping clone."
fi

# Overwrite current files with files from the overwrite folder
if [ -d "$OVERWRITE_DIR" ]; then
    echo "Overwriting files from $OVERWRITE_DIR to $TARGET_PATH..."
    find "$OVERWRITE_DIR" -type f | while read -r file; do
        relative_path="${file#"$OVERWRITE_DIR"/}"
        target_file="$TARGET_PATH/$relative_path"
        target_dir=$(dirname "$target_file")
        filename=$(basename "$file")

        if [[ "$filename" == *.patch ]]; then
            # Calculate the target file path without .patch extension
            relative_path_without_patch="${relative_path%.patch}"
            target_file_for_patch="$TARGET_PATH/$relative_path_without_patch"

            # Check if the target file exists
            if [ -f "$target_file_for_patch" ]; then
                # Check if patch is already applied using dry-run
                if patch --dry-run -p0 "$target_file_for_patch" < "$file" > /dev/null 2>&1; then
                    echo "Applying patch $file to $target_file_for_patch..."
                    
                    # Apply the patch
                    if patch -p0 "$target_file_for_patch" < "$file"; then
                        echo "Successfully patched: $target_file_for_patch"
                    else
                        echo "Warning: Failed to apply patch $file to $target_file_for_patch" >&2
                        # Continue with other files instead of exiting
                    fi
                else
                    echo "Patch $file appears to be already applied to $target_file_for_patch, skipping..."
                fi
            else
                echo "Warning: Target file $target_file_for_patch does not exist for patch $file" >&2
            fi
        else
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
        fi
    done
    echo "All files from $OVERWRITE_DIR have been successfully copied to $TARGET_PATH."
else
    echo "Overwrite directory $OVERWRITE_DIR does not exist. Skipping overwrite."
fi

# Copy the intel_xpu folder into the TARGET_PATH directory
if [ -d "$XPU_OVERWRITE_FOLDER" ]; then
    echo "Copying $XPU_OVERWRITE_FOLDER to $TARGET_PATH..."
    cp -r "$XPU_OVERWRITE_FOLDER" "$TARGET_PATH/"
    echo "$XPU_OVERWRITE_FOLDER copied successfully."
else
    echo "No folder found at $XPU_OVERWRITE_FOLDER. Skipping copy."
fi
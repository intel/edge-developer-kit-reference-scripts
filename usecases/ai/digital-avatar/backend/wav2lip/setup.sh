#!/bin/bash

# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# Check if required commands are available
if ! command -v git &> /dev/null; then
    echo "Error: git command not found. Please install git." >&2
    exit 1
fi

if ! command -v patch &> /dev/null; then
    echo "Error: patch command not found. Please install patch utility." >&2
    exit 1
fi

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
    if git clone --depth 1 --single-branch --filter=blob:none --sparse "$REPO_URL" "$FOLDER_DIR"; then
        echo "Repository cloned successfully into $FOLDER_DIR."
        
        # Configure sparse checkout to only include the Wav2Lip directory
        cd "$FOLDER_DIR" || {
            echo "Error: Failed to change to $FOLDER_DIR directory" >&2
            exit 1
        }
        
        echo "Configuring sparse checkout for $WAV2LIP_DIR..."
        git sparse-checkout init --cone
        git sparse-checkout set "$WAV2LIP_DIR"
        
        cd .. || {
            echo "Error: Failed to return to parent directory" >&2
            exit 1
        }

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
            echo "Processing files from $OVERWRITE_DIR to $FOLDER_DIR..."
            find "$OVERWRITE_DIR" -type f | while read -r file; do
                relative_path="${file#"$OVERWRITE_DIR"/}"
                filename=$(basename "$file")
                
                # Check if this is a patch file
                if [[ "$filename" == *.patch ]]; then
                    # Extract the original filename (remove .patch extension)
                    original_filename="${filename%.patch}"
                    target_file="$FOLDER_DIR/$original_filename"
                    
                    # Check if the target file exists
                    if [ -f "$target_file" ]; then
                        if patch --dry-run -p0 "$target_file" < "$file" > /dev/null 2>&1; then
                            echo "Applying patch $file to $target_file..."
                            
                            # Apply the patch
                            if patch -p0 "$target_file" < "$file"; then
                                echo "Successfully patched: $target_file"
                            else
                                echo "Warning: Failed to apply patch $file to $target_file" >&2
                                # Continue with other files instead of exiting
                            fi
                        else
                            echo "Patch $file appears to be already applied to $target_file, skipping..."
                        fi
                    else
                        echo "Warning: Target file $target_file does not exist for patch $file" >&2
                    fi
                else
                    # Regular file - copy as before
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
                fi
            done
            echo "All files from $OVERWRITE_DIR have been successfully processed to $FOLDER_DIR."
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
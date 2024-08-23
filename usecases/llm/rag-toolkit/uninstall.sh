#!/bin/bash
# INTEL CONFIDENTIAL
# Copyright (C) 2024, Intel Corporation

WORKDIR=$PWD
S_VALID="✓"

if [ "$EUID" -eq 0 ]; then
    echo "Must not run with sudo or root user"
    exit 1
fi

remove_python3_env(){
    echo -e "- Removing the python3 environment"
    if [ -d "$WORKDIR/.venv" ]; then
        rm -rf "$WORKDIR"/.venv
        echo -e "$S_VALID Successfully removed python3 environment\n"
    fi
}

remove_device(){
    echo -e "- Removing the .device file"
    if [ -f "$WORKDIR/.device" ]; then
        rm "$WORKDIR"/.device
        echo -e "$S_VALID Successfully removed .device file\n"
    fi
}

remove_ui_build_files(){
    echo -e "- Removing the UI cache files"
    if [ -d "$WORKDIR/edge-ui/.next" ]; then
        rm -rf "$WORKDIR"/edge-ui/.next
    fi

    if [ -d "$WORKDIR/edge-ui/node_modules" ]; then
        rm -rf "$WORKDIR"/edge-ui/node_modules
    fi
    echo -e "$S_VALID Successfully removed UI cache files\n"
}

remove_thirdparty_dir(){
    echo -e "- Removing the thirdparty directory"
    if [ -d "$WORKDIR/thirdparty" ]; then
        rm -rf "$WORKDIR"/thirdparty
        echo -e "$S_VALID Successfully removed thirdparty directory\n"
    fi
}

remove_temp_dir(){
    echo -e "- Removing the temporary directory"
    if [ -d "$WORKDIR/data/temp" ]; then
        rm -rf "$WORKDIR"/data/temp
        echo -e "$S_VALID Successfully removed temporary directory\n"
    fi
}

uninstall(){
    remove_python3_env
    remove_thirdparty_dir
    remove_ui_build_files
    remove_device
    remove_temp_dir
}

entrypoint(){
    echo -e "################################"
    echo -e "# Intel® LLM On Edge Uninstall #"
    echo -e "################################"
    echo -e ""
    read -rp "Are you sure you want to uninstall the application? (y/n): " choice
    case $choice in
    y)
        uninstall
        ;;
    n)
        exit 0
        ;;
    *)
        echo "Invalid choice. Please enter y or n."
        exit 1
        ;;
    esac
    echo -e "Successfully uninstall the application. You can reinstall the application by running the install.sh script again"
}

entrypoint
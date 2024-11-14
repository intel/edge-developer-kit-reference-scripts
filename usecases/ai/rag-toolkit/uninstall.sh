#!/bin/bash
# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

if [ "$EUID" -eq 0 ]; then
    echo "Must not run with sudo or root user"
    exit 1
fi

print_info(){
    local info="$1"
    echo -e "\n# $info"
}

remove_python3_env(){
    print_info "Removing the python3 environment"
    if [ -d "./.venv" ]; then
        rm -rf ./.venv
        echo -e "- Successfully removed python3 environment"
    fi
}

remove_ui_build_files(){
    print_info "Removing the UI cache files"
    if [ -d "./edge-ui/.next" ]; then
        rm -rf ./edge-ui/.next
        echo -e "- Successfully removed UI cache"
    fi

    if [ -d "./edge-ui/node_modules" ]; then
        rm -rf ./edge-ui/node_modules
        echo -e "- Successfully removed UI node_modules"
    fi
}

remove_thirdparty_dir(){
    print_info "Removing the thirdparty directory"
    if [ -d "./thirdparty" ]; then
        rm -rf ./thirdparty
        echo -e "- Successfully removed thirdparty directory"
    fi
}

remove_lock(){
    print_info "Removing lockfile for installation"
    if [ -f "./.framework" ]; then
        rm -rf ./.framework
        echo -e "- Successfully removed the lockfile"
    fi
}

remove_ollama_cache(){
    print_info "Removing ollama cache"
    if [ -d "./data/model/ollama" ]; then
        rm -rf ./data/model/ollama
        echo -e "- Successfully removed the ollama cache"
    fi

    if [ -d "./data/model/gguf" ]; then
        rm -rf ./data/model/gguf
        echo -e "- Successfully removed the gguf cache"
    fi
}

uninstall(){
    remove_python3_env
    remove_thirdparty_dir
    remove_lock
    remove_ui_build_files
    remove_ollama_cache
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
    print_info "Successfully uninstall the application. You can reinstall the application by running the install.sh script again"
}

entrypoint
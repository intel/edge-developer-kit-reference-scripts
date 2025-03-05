# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

#----------------------------------------------------------------------------------------------------------------------
# Flags
#----------------------------------------------------------------------------------------------------------------------
SHELL := /bin/bash
CURRENT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

DOCKER_IMAGE_NAME = vision_edge_ai
SERVICE_NAME = vision_edge_ai  

# Proxy settings (default to empty if not set)
PORT ?= 80
export PORT

HOST_ADDRESS="0.0.0.0"
export HOST_ADDRESS

#----------------------------------------------------------------------------------------------------------------------
# Docker Settings
#----------------------------------------------------------------------------------------------------------------------
export DOCKER_BUILDKIT=1

DOCKER_COMPOSE_ENV = \
	DOCKER_IMAGE_NAME=$(DOCKER_IMAGE_NAME) \
	HTTP_PROXY=$(HTTP_PROXY) \
	HTTPS_PROXY=$(HTTPS_PROXY) \
	NO_PROXY=$(NO_PROXY) \
	MKL_THREADING_LAYER=gnu \
	CURRENT_DIR=$(CURRENT_DIR) \
	PORT=${PORT} \
	HOST_ADDRESS=$(HOST_ADDRESS) \
	CUSTOM_LOGO_IMAGE=$(CUSTOM_LOGO_IMAGE)

#----------------------------------------------------------------------------------------------------------------------
# Targets
#----------------------------------------------------------------------------------------------------------------------
default: run

.PHONY: build app run bash

build: 
	@$(call msg, Building Docker image ${DOCKER_IMAGE_NAME} ...)
	@$(DOCKER_COMPOSE_ENV) docker compose build  
	
run: stop
	@$(call msg, Running the Vision Edge AI application ...)
	@docker compose up 

stop: build
	@$(call msg, Stopping the Vision Edge AI application ...)
	@docker compose down 

install_prerequisites:
	@$(call msg, Installing Prerequisites ...)
	@cd ./tools && bash ./install.sh

bash: build
	@$(call msg, Opening a bash session in the container ...)
	@docker-compose run --rm $(SERVICE_NAME) bash


enable_auto_start: build
	@$(call msg, Configuring Vision Edge AI to start automatically on system boot ...)
	@if [ ! -f $(CURRENT_DIR)/utils/vision_edge_ai.service ]; then \
		echo "Error: utils/vision_edge_ai.service file not found"; \
		exit 1; \
	fi

	@sed 's|{{CURRENT_DIR}}|$(CURRENT_DIR)|g; s|{{DOCKER_IMAGE_NAME}}|$(DOCKER_IMAGE_NAME)|g; s|{{PORT}}|$(PORT)|g; s|{{HOST_ADDRESS}}|$(HOST_ADDRESS)|g' \
		$(CURRENT_DIR)/utils/vision_edge_ai.service | sudo tee /etc/systemd/system/vision_edge_ai.service > /dev/null

	@sudo systemctl daemon-reload
	@sudo systemctl enable vision_edge_ai.service
	@echo "Auto-start enabled. Use 'sudo systemctl start vision_edge_ai' to start now,"
	@echo "or reboot the system to verify automatic startup."

disable_auto_start: build
	@$(call msg, Disabling auto start ...)
	@sudo systemctl stop vision_edge_ai.service
	@sudo systemctl disable vision_edge_ai.service

#----------------------------------------------------------------------------------------------------------------------
# Helper Functions
#----------------------------------------------------------------------------------------------------------------------
define msg
	tput setaf 2 && \
	for i in $(shell seq 1 120 ); do echo -n "-"; done; echo  "" && \
	echo "         "$1 && \
	for i in $(shell seq 1 120 ); do echo -n "-"; done; echo "" && \
	tput sgr0
endef


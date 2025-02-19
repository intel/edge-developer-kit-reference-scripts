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
	HOST_ADDRESS=$(HOST_ADDRESS)

#----------------------------------------------------------------------------------------------------------------------
# Targets
#----------------------------------------------------------------------------------------------------------------------
default: run

.PHONY: build app run bash

build:
	@$(call msg, Building Docker image ${DOCKER_IMAGE_NAME} ...)
	@$(DOCKER_COMPOSE_ENV) docker-compose build
	@docker-compose run --rm $(SERVICE_NAME) bash -c \
		'cd ./utils/ && python3 setup.py build_ext --quiet --inplace'

run: stop
	@$(call msg, Running the Vision Edge AI application ...)
	@docker-compose up -d

stop: build
	@$(call msg, Stopping the Vision Edge AI application ...)
	@docker-compose down --remove-orphans  # Ensure old orphaned containers are removed

install_prerequisites:
	@$(call msg, Installing Prerequisites ...)
	@cd ./tools && bash ./install.sh


bash:
	@$(call msg, Opening a bash session in the container ...)
	@docker-compose run --rm $(SERVICE_NAME) bash

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


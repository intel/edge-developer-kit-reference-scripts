# Use a minimal Debian base image for a smaller container footprint
FROM debian:12-slim

# Avoid interactive prompts during package installation
ARG DEBIAN_FRONTEND=noninteractive

# Define the default allowed models and the default model
ARG DEFAULT_MODEL="stable-diffusion-v3.5"
ARG HOST="0.0.0.0"
ARG PORT="8100"

# Set environment variables for the default model and allowed models
ENV ALLOWED_MODELS="stable-diffusion-v3.5 stable-diffusion-xl flux-schnell"
ENV DEFAULT_MODEL=${DEFAULT_MODEL}
ENV HOST=${HOST}
ENV PORT=${PORT}

# Do checking if the default model is in the allowed models list
RUN if [[ ! "${ALLOWED_MODELS}" =~ "${DEFAULT_MODEL}" ]]; then \
        echo "Error: The default model '${DEFAULT_MODEL}' is not in the allowed models list." >&2; \
        exit 1; \
    fi

# Ensure the container is running as root for package installations
USER root

# Install system dependencies, including Python 3.11 and venv
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ffmpeg \
        curl \
        git \
        gnupg2 \
        libtbb12 \
        python3.11 \
        python3.11-venv \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Intel GPU drivers with error handling and version pinning
WORKDIR /tmp/neo
RUN curl -sSLO https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.17791.9/intel-igc-core_1.0.17791.9_amd64.deb \
    && curl -sSLO https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.17791.9/intel-igc-opencl_1.0.17791.9_amd64.deb \
    && curl -sSLO https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/intel-level-zero-gpu_1.6.31294.12_amd64.deb \
    && curl -sSLO https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/intel-opencl-icd_24.39.31294.12_amd64.deb \
    && curl -sSLO https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/libigdgmm12_22.5.2_amd64.deb \
    && dpkg -i *.deb \
    && rm -rf /tmp/neo

# Install Intel NPU drivers with error handling and version pinning
WORKDIR /tmp/npu-driver
RUN curl -sSLO https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-driver-compiler-npu_1.10.0.20241107-11729849322_ubuntu22.04_amd64.deb \
    && curl -sSLO https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-fw-npu_1.10.0.20241107-11729849322_ubuntu22.04_amd64.deb \
    && curl -sSLO https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-level-zero-npu_1.10.0.20241107-11729849322_ubuntu22.04_amd64.deb \
    && curl -sSLO https://github.com/oneapi-src/level-zero/releases/download/v1.17.6/level-zero_1.17.6+u22.04_amd64.deb \
    && dpkg -i *.deb \
    && rm -rf /tmp/npu-driver

# Create a non-root user for OpenVINO and avoid privilege escalation
RUN groupadd -r openvino && useradd -r -g openvino -G video openvino

# Set up a dedicated home directory for the user
RUN mkdir -p /home/openvino && \
    chown -R openvino:openvino /home/openvino

USER openvino
WORKDIR /usr/src/app/${DEFAULT_MODEL}

# Create a virtual environment for the default model and install dependencies
RUN python3 -m venv .venv
ENV PATH="/usr/src/app/${DEFAULT_MODEL}/.venv/bin:$PATH"
COPY --chown=openvino:openvino ./${DEFAULT_MODEL}/requirements.txt .
RUN python3 -m pip install --no-cache-dir --upgrade pip \
    && python3 -m pip install --no-cache-dir -r requirements.txt

# Copy the model files and scripts into the container
COPY --chown=openvino:openvino ./${DEFAULT_MODEL} .

# Expose port for the microservice
EXPOSE ${PORT}

# Set the entrypoint to the server script
CMD ["bash", "-c", "python3 backend/server.py"]

# Add a basic health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -f http://localhost:${PORT}/health || exit 1

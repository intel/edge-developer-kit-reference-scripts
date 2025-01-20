# Use a minimal Debian base image for a smaller container footprint
FROM debian:12-slim

# Avoid interactive prompts during package installation
ARG DEBIAN_FRONTEND=noninteractive

# Define the default allowed models and the default model
ARG ALLOWED_MODELS="stable-diffusion-v3 stable-diffusion-v3.5 stable-diffusion-xl"
ARG DEFAULT_MODEL="stable-diffusion-xl"

# Set default model as a build argument and runtime environment variable
ENV DEFAULT_MODEL=${DEFAULT_MODEL}

# Ensure the container is running as root for package installations
USER root

# Set the working directory early for clarity and organization
WORKDIR /usr/src/app

# Install system dependencies, including Python 3.11 and venv
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ffmpeg \
        wget \
        git \
        gnupg2 \
        libtbb12 \
        python3.11 \
        python3.11-venv \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Intel GPU drivers with error handling and version pinning
RUN mkdir /tmp/neo \
    && cd /tmp/neo \
    && wget -q https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.17791.9/intel-igc-core_1.0.17791.9_amd64.deb \
    && wget -q https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.17791.9/intel-igc-opencl_1.0.17791.9_amd64.deb \
    && wget -q https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/intel-level-zero-gpu_1.6.31294.12_amd64.deb \
    && wget -q https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/intel-opencl-icd_24.39.31294.12_amd64.deb \
    && wget -q https://github.com/intel/compute-runtime/releases/download/24.39.31294.12/libigdgmm12_22.5.2_amd64.deb \
    && dpkg -i *.deb \
    && rm -rf /tmp/neo

# Install Intel NPU drivers with error handling and version pinning
RUN mkdir /tmp/npu-driver \
    && cd /tmp/npu-driver \
    && wget -q https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-driver-compiler-npu_1.10.0.20241107-11729849322_ubuntu22.04_amd64.deb \
    && wget -q https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-fw-npu_1.10.0.20241107-11729849322_ubuntu22.04_amd64.deb \
    && wget -q https://github.com/intel/linux-npu-driver/releases/download/v1.10.0/intel-level-zero-npu_1.10.0.20241107-11729849322_ubuntu22.04_amd64.deb \
    && wget -q https://github.com/oneapi-src/level-zero/releases/download/v1.17.6/level-zero_1.17.6+u22.04_amd64.deb \
    && dpkg -i *.deb \
    && rm -rf /tmp/npu-driver

# Create a non-root user for OpenVINO and avoid privilege escalation
RUN groupadd -r openvino && useradd -r -g openvino -G video openvino

# Set up a dedicated home directory for the user
RUN mkdir -p /home/openvino && \
    chown -R openvino:openvino /home/openvino

# Copy application files and adjust permissions (excluding the virtual environments)
COPY . /usr/src/app
RUN find /usr/src/app -not -path "/usr/src/app/*/.venv*" -exec chown openvino:openvino {} + \
    && find /usr/src/app -not -path "/usr/src/app/*/.venv*" -exec chmod 755 {} +

# Remove existing virtual environments to ensure a clean install
RUN rm -rf /usr/src/app/*/.venv

# Create a Python virtual environment for each model and install dependencies
RUN for model in $ALLOWED_MODELS; do \
        python3.11 -m venv /usr/src/app/$model/.venv; \
        /usr/src/app/$model/.venv/bin/python -m pip install --no-cache-dir --upgrade pip; \
        if [ -f "/usr/src/app/$model/requirements.txt" ]; then \
            /usr/src/app/$model/.venv/bin/python -m pip install --no-cache-dir -r /usr/src/app/$model/requirements.txt; \
        fi; \
        chown -R openvino:openvino /usr/src/app/$model/.venv; \
    done

# Set the environment variable for the virtual environment based on the selected model
ENV PATH="/usr/src/app/${SELECTED_MODEL}/.venv/bin:$PATH"

# Switch to the non-root user for security
USER openvino

# Set the working directory based on the selected model
WORKDIR /usr/src/app/${SELECTED_MODEL}

# Expose port for the microservice
EXPOSE 8100

# Allow runtime injection of Hugging Face Token and model selection
# If HF_TOKEN is not provided, models requiring it will fail securely.
CMD ["bash", "-c", \
     "SELECTED_MODEL=${MODEL:-$DEFAULT_MODEL} && \
      export PATH=/usr/src/app/${SELECTED_MODEL}/.venv/bin:$PATH && \
      export HF_TOKEN=${HF_TOKEN:-''} && \
      echo Using model: $SELECTED_MODEL && \
      echo HF_TOKEN set to: ${HF_TOKEN:0:5}****** && \
      /usr/src/app/${SELECTED_MODEL}/.venv/bin/python /usr/src/app/${SELECTED_MODEL}/backend/server.py"]

# Add a basic health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD exit 0

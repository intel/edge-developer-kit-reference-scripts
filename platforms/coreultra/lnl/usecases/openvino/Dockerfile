# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM openvino/ubuntu24_dev:devkit

COPY npu_container.sh /tmp/npu_container.sh
USER root
ENV NPU_SETUP=false
RUN apt-get update \
    && apt-get install -y --no-install-recommends wget gnupg curl libtbbmalloc2 libtbb12 kmod
RUN set -o pipefail && wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
    gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg && \
    echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu noble client" | \
    tee /etc/apt/sources.list.d/intel-gpu-noble.list
RUN apt update \
    && apt-get install -y --no-install-recommends libze1 intel-opencl-icd clinfo intel-gsc clinfo vainfo hwinfo
RUN groupadd -g 110 render \
    && usermod -aG render openvino
RUN usermod -aG video openvino

# Install compute runtime
RUN mkdir -p /tmp/neo_temp
WORKDIR /tmp/neo_temp
RUN wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.5.6/intel-igc-core-2_2.5.6+18417_amd64.deb \
    && wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.5.6/intel-igc-opencl-2_2.5.6+18417_amd64.deb \
    && wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-level-zero-gpu-dbgsym_1.6.32224.5_amd64.ddeb \
    && wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-level-zero-gpu_1.6.32224.5_amd64.deb \
    && wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-opencl-icd-dbgsym_24.52.32224.5_amd64.ddeb \
    && wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-opencl-icd_24.52.32224.5_amd64.deb \
    && wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/libigdgmm12_22.5.5_amd64.deb

RUN echo -e "Verify sha256 sums for packages"
RUN wget https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/ww52.sum \
    && sha256sum -c ww52.sum

RUN echo -e "\nInstalling compute runtime"
RUN dpkg -i ./*.deb
USER openvino

CMD ["/tmp/npu_container.sh"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
    CMD sh -c "set -o pipefail && clinfo | grep 'Driver Version' | awk '{print $NF}' || exit 1"
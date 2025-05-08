# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM openvino/ubuntu22_dev:devkit

COPY npu_container.sh /tmp/npu_container.sh
USER root
ENV NPU_SETUP=false
RUN apt-get update \
    && apt-get install -y --no-install-recommends wget gnupg curl libtbbmalloc2 libtbb12 kmod
RUN set -o pipefail && wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
    gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg && \
    echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | \
    tee /etc/apt/sources.list.d/intel-gpu-jammy.list
RUN apt update \
    && apt-get install -y --no-install-recommends libze1 intel-level-zero-gpu intel-opencl-icd clinfo vainfo hwinfo
RUN groupadd -g 110 render \
    && usermod -aG render openvino
RUN usermod -aG video openvino
USER openvino

CMD ["/tmp/npu_container.sh"]

HEALTHCHECK NONE
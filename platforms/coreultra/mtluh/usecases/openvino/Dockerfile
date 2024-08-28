# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

FROM openvino/ubuntu22_dev:devkit

COPY npu_container.sh /tmp/npu_container.sh

USER openvino

CMD ["/tmp/npu_container.sh"]

HEALTHCHECK NONE
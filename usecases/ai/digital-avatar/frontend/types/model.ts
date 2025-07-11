// Copyright(C) 2024 Intel Corporation
// SPDX - License - Identifier: Apache - 2.0

export interface ModelDetails {
    parent_model: string;
    format: string;
    family: string;
    families: string[];
    parameter_size: string;
    quantization_level: string;
}

export interface LLMModel {
    id: string;
    created: number;
    object: string;
    owened_by: string;
}

export interface LLMModelsResponse {
    data: LLMModel[];
}

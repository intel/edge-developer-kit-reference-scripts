// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"

import { useMutation, UseMutationResult, useQuery, UseQueryResult } from "@tanstack/react-query";

import { FetchAPI } from "@/lib/api";
import { APIResponse } from "@/types/api";
import { LLMModel } from "@/types/model";
import { handleAPIResponse } from "@/utils/common";

const LLMAPI = new FetchAPI(`/api/llm`);

export const useGetLLM = (): UseQueryResult<{ models: LLMModel[] }, Error> => {
    return useQuery({
        queryKey: ['llm_models'],
        queryFn: async () => {
            const response = await LLMAPI.get('models')
            const result = handleAPIResponse<{ models: LLMModel[] }>(response);
            return result ?? null;
        },
    });

}

export const usePullLLM = (): UseMutationResult<APIResponse, Error, { data: { model: string } }> => {
    return useMutation({
        mutationFn: async ({
            data
        }: { data: { model: string } }) => {
            const response = await LLMAPI.post('pull', data)
            return response
        },
    });
}
// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"

import { useMutation, UseMutationResult, useQuery, UseQueryResult } from "@tanstack/react-query";

import { FetchAPI } from "@/lib/api";
import { APIResponse } from "@/types/api";
import { LLMModel } from "@/types/model";
import { constructURL, handleAPIResponse } from "@/utils/common";
import { CreateTextBeddingsProps } from "@/types/dataset";

const LLMAPI = new FetchAPI(`/api/llm`);

export const useGetLLM = (): UseQueryResult<{ data: LLMModel[], object: string }, Error> => {
    return useQuery({
        queryKey: ['llm_models'],
        queryFn: async () => {
            const response = await LLMAPI.get('models')
            const result = handleAPIResponse<{ data: LLMModel[], object: string }>(response);
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

export const useCreateTextEmbeddings = (): UseMutationResult<
    APIResponse,
    Error,
    CreateTextBeddingsProps
> => {
    return useMutation({
        mutationFn: async ({
            chunkSize,
            chunkOverlap,
            data,
        }: CreateTextBeddingsProps) => {
            const response = await LLMAPI.post(
                `rag/text_embeddings?chunk_size=${chunkSize}&chunk_overlap=${chunkOverlap}`,
                data,
                { headers: {} }
            );
            return response;
        },
    });
};

export function useGetDatasetEmbeddings() {
  return useQuery({
      queryKey: [''],
      queryFn: async () => {
          const response = await LLMAPI.get('rag/text_embedding_sources')
          return response
      },
  });
};

export const getDatasetEmbeddingsAPI = async (
    page?: number,
    pageSize?: number,
    source?: string
): Promise<APIResponse> => {
    const url = `rag/text_embeddings`;
    const fullURL = source
        ? constructURL(url, page, pageSize, { source })
        : constructURL(url, page, pageSize);
    const response = await LLMAPI.get(fullURL);
    return response;
};

export function useGetDatasetEmbeddingSources() {
  return useQuery({
      queryKey: [''],
      queryFn: async () => {
          const response = await LLMAPI.get('rag/text_embedding_sources')
          return response
      },
  });
};

export const useDeleteTextEmbeddingByUUID = (): UseMutationResult<
    APIResponse,
    Error,
    { uuid: string }
> => {
    return useMutation({
        mutationFn: async ({ uuid }: { uuid: string }) => {
            return await LLMAPI.delete(`rag/text_embeddings/${uuid}`);
        },
    });
};

export const useDeleteTextEmbeddingBySource = (): UseMutationResult<
    APIResponse,
    Error,
    { source: string }
> => {
    return useMutation({
        mutationFn: async ({ source }: { source: string }) => {
            return await LLMAPI.delete(`rag/text_embeddings/source/${source}`);
        },
    });
};

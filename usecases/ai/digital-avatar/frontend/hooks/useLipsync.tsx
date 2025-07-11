// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"

import { useMutation, useQuery, UseQueryResult } from "@tanstack/react-query";

import { FetchAPI } from "@/lib/api";
import { handleAPIResponse } from "@/utils/common";
import { LipsyncConfigApiResponse, LipsyncSelectedConfig } from "@/types/config";

const LipsyncAPI = new FetchAPI(`/api/lipsync`);

export const useGetLipsyncConfig = (): UseQueryResult<LipsyncConfigApiResponse, Error> => {
    return useQuery({
        queryKey: ['get-lipsync-config'],
        queryFn: async () => {
            const response = await LipsyncAPI.get('config')
            const result = handleAPIResponse<LipsyncConfigApiResponse>(response);
            return result ?? null;
        },
    });

}

export function useUpdateLipsyncConfig() {
    return useMutation({
        mutationFn: async (config: LipsyncSelectedConfig) => {
            const response = await LipsyncAPI.post('update_config', config);
            const result = handleAPIResponse(response);
            if (!result) {
                throw new Error('Failed to update configuration');
            }
            return result;
        },
    });
}

export function useGetLipsync() {
    return useMutation({
        mutationFn: async ({
            data, startIndex, reversed
        }: { data: { filename: string }, startIndex: string, reversed: string }) => {
            const start = performance.now() / 1000;
            const response = await LipsyncAPI.post(`inference_from_filename?starting_frame=${startIndex}&reversed=${reversed}&enhance=${true}`, { filename: data.filename })
            const totalLatency = performance.now() / 1000 - start;

            // add httpLatency to the response data
            const httpLatency = totalLatency - (response.data.inference_latency);
            response.data = {
                ...response.data,
                http_latency: httpLatency,
            }
            return response
        },
    });
}
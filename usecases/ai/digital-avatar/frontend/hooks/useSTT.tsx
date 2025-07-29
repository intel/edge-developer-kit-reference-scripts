// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"

import { useMutation, UseMutationResult } from "@tanstack/react-query";

import { FetchAPI } from "@/lib/api";

const STTAPI = new FetchAPI(`/api/stt`);
// const STTAPI = new FetchAPI(`${process.env.NEXT_PUBLIC_STT_URL}`);

export function useGetSTT(): UseMutationResult<Record<string, any>, Error, { data: FormData }> {
    return useMutation({
        mutationFn: async ({
            data
        }: { data: FormData }) => {
            try {
                const start = performance.now() / 1000;
                const response = await STTAPI.file('audio/transcriptions', data, { headers: {} })
                const totalLatency = performance.now() / 1000 - start;
                
                // add httpLatency to the response data.metrics
                const responseJson = await response.json();
                const httpLatency = totalLatency - (responseJson.metrics?.denoise_latency + responseJson.metrics?.stt_latency);
                responseJson.metrics = {
                    ...responseJson.metrics,
                    http_latency: httpLatency,
                }
                return responseJson
                // return await response.json()
            } catch (error) {
                return { status: false, message: "Failed to process audio", data: error }
            }
        },
    });
}
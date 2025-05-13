// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"

import { useMutation } from "@tanstack/react-query";

import { FetchAPI } from "@/lib/api";

const LipsyncAPI = new FetchAPI(`/api/lipsync`);
// const LipsyncAPI = new FetchAPI(`${process.env.NEXT_PUBLIC_LIPSYNC_URL}`);

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
// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"

import { useMutation } from "@tanstack/react-query";

import { FetchAPI } from "@/lib/api";

const TTSAPI = new FetchAPI(`/api/tts`);
// const TTSAPI = new FetchAPI(`${process.env.NEXT_PUBLIC_TTS_URL}`);

export function useGetTTSAudio() {
    return useMutation({
        mutationFn: async ({
            text
        }: { text: string }) => {
            const start = performance.now() / 1000;
            const response = await TTSAPI.post('audio/speech', { text, keep_file: true })
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
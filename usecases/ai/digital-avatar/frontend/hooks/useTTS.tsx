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
            text, speaker
        }: { text: string, speaker: string }) => {
            const response = await TTSAPI.post('audio/speech', { text, speaker, keep_file: true })
            return response
        },
    });
}
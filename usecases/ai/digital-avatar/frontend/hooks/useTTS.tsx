// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"

import { useMutation } from "@tanstack/react-query";

import { FetchAPI } from "@/lib/api";

const TTSAPI = new FetchAPI(`${process.env.NEXT_PUBLIC_TTS_URL}`);

export function useGetTTSAudio() {
    return useMutation({
        mutationFn: async ({
            text, speaker
        }: { text: string, speaker: string }) => {
            // const response = await fetch("/api/tts", { method: "POST", body: JSON.stringify({ input: text, voice: "EN-US", model: " - " }) })
            const response = await TTSAPI.file('audio/speech', { text, speaker })
            return await response.blob()
        },
    });
}
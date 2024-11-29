"use client"

import { useMutation } from "@tanstack/react-query";

import { FetchAPI } from "@/lib/api";

const TTSAPI = new FetchAPI(`${process.env.NEXT_PUBLIC_TTS_URL}`);

export function useGetTTSAudio() {
    return useMutation({
        mutationFn: async ({
            text
        }: { text: string }) => {
            // const response = await fetch("/api/tts", { method: "POST", body: JSON.stringify({ input: text, voice: "EN-US", model: " - " }) })
            const response = await TTSAPI.file('audio/speech', { input: text, voice: "EN-US", model: "-", speed: 1.2 })
            return await response.blob()
        },
    });
}
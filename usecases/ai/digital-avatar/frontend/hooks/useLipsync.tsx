"use client"

import { useMutation } from "@tanstack/react-query";

import { FetchAPI } from "@/lib/api";

const LipsyncAPI = new FetchAPI(`${process.env.NEXT_PUBLIC_LIPSYNC_URL}`);

export function useGetLipsync() {
    return useMutation({
        mutationFn: async ({
            data
        }: { data: FormData }) => {
            // const response = await fetch("/api/lipsync", { body: data, method: "POST" })
            const response = await LipsyncAPI.file('inference', data, { headers: {} })
            return await response.blob()
        },
    });
}
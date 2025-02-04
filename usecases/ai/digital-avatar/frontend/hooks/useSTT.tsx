// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"

import { useMutation, UseMutationResult } from "@tanstack/react-query";

import { FetchAPI } from "@/lib/api";

const STTAPI = new FetchAPI(`${process.env.NEXT_PUBLIC_STT_URL}`);

export function useGetSTT(): UseMutationResult<Record<string, any>, Error, { data: FormData }> {
    return useMutation({
        mutationFn: async ({
            data
        }: { data: FormData }) => {
            try {
                const response = await STTAPI.file('audio/transcriptions', data, { headers: {} })
                return await response.json()
            } catch (error) {
                return { status: false, message: "Failed to process audio", data: error }
            }
        },
    });
}
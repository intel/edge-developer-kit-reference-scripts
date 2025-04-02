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
        }: { data: { filename: string, expressionScale: number }, startIndex: string, reversed: string }) => {
            // const response = await fetch("/api/lipsync", { body: data, method: "POST" })
            // const response = await LipsyncAPI.post(`inference_from_filename?starting_frame=${startIndex}&reversed=${reversed}&enhance=${true}`, { filename: data.filename, expression_scale: data.expressionScale })
            const response = await LipsyncAPI.post(`inference_from_filename?starting_frame=${startIndex}&reversed=${reversed}&enhance=${true}`, { filename: data.filename })
            return response
        },
    });
}
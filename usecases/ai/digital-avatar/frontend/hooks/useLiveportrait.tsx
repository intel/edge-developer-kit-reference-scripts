// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"

import { useMutation, useQuery } from "@tanstack/react-query";

import { FetchAPI } from "@/lib/api";

const LiveportraitAPI = new FetchAPI(`/api/liveportrait`);

export function useCreateAvatarSkin() {
  return useMutation({
    mutationFn: async ({
      data
    }: { data: FormData }) => {
      try {
        const response = await LiveportraitAPI.file('inference', data, { headers: {} })
        return await response.json()
      } catch (error) {
        return { status: false, message: "Failed to process asset", data: error }
      }
    },
  });
}

export function useGetAvatarSkinTask({ enabled = false, refetchInterval = 15000 } = {}) {
  return useQuery({
    queryKey: ["avatar-skin-task"],
    queryFn: async () => {
      try {
        const response = await LiveportraitAPI.get("get-task");
        return response;
      } catch (error) {
        return { status: false, message: "Failed to get task", data: error };
      }
    },
    refetchInterval: enabled ? refetchInterval : false,
  });
}
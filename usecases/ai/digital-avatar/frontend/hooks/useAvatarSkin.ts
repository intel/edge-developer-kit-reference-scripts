// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"

import { useMutation, UseMutationResult, useQuery, UseQueryResult } from "@tanstack/react-query";

import { FetchAPI } from "@/lib/api";
import { Skin } from "@/types/avatar-skins";
import { handleAPIResponse } from "@/utils/common";
import { APIResponse } from "@/types/api";

const AvatarSkinAPI = new FetchAPI(`/api/avatar-skins`);

export const useGetAvatarSkin = (): UseQueryResult<Skin[], Error> => {
  return useQuery({
    queryKey: ['avatar-skins'],
    queryFn: async () => {
      const response = await AvatarSkinAPI.get('/')
      const result = handleAPIResponse<Skin[]>(response);
      return result ?? null;
    },
  });
}

export const useDeleteAvatarSkin = (): UseMutationResult<
  APIResponse,
  Error,
  { skinName: string }
> => {
  return useMutation({
    mutationFn: async ({ skinName }: { skinName: string }) => {
      return await AvatarSkinAPI.delete(`/?skinName=${encodeURIComponent(skinName)}`);
    },
  });
};

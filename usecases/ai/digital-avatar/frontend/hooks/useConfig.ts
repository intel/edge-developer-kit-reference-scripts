// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"

import { useMutation, UseMutationResult, useQuery } from "@tanstack/react-query";

import { FetchAPI } from "@/lib/api";
import { handleAPIResponse } from "@/utils/common";
import { Configs, SelectedPipelineConfig } from "@/types/config";
import { APIResponse } from "@/types/api";

const ConfigAPI = new FetchAPI(`/api/config`);

export function useGetConfig() {
  return useQuery({
      queryKey: [''],
      queryFn: async () => {
          const response = await ConfigAPI.get('/')
          const result = handleAPIResponse<Configs>(response);
          return {
              data: result,
              status: response.status,
              url: response.url,
          } as APIResponse;
      },
  });
}

export const useUpdateConfig = (): UseMutationResult<
  Configs,
  Error,
  Partial<SelectedPipelineConfig>
> => {
  return useMutation({ 
    mutationFn: async (config: Partial<SelectedPipelineConfig>) => {
      const response = await ConfigAPI.post('/', config);
      const result = handleAPIResponse<Configs>(response);
      if (!result) {
        throw new Error('Failed to update configuration');
      }
      return result;
    },
  });
};
// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import { type APIResponse } from "@/types/api";
import { API } from "@/utils/api";

export const getModelIdAPI = async (): Promise<APIResponse> => {
    const url = `models`;
    try {
        const response = await API.get(url, { revalidate: 0 });
        return response;
    } catch (error) {
        return { status: false, message: 'Error processing request', url: '' };
    }
};
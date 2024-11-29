// INTEL CONFIDENTIAL
// Copyright (C) 2024, Intel Corporation

export interface APIResponse {
    status: boolean;
    url: string;
    data?: any;
    message?: string;
    detail?: any;
}

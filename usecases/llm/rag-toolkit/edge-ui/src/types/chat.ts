// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

export interface Message {
    role: 'user' | 'assistant',
    content: string,
    status: string,
}
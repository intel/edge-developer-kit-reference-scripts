// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import OpenAI from "openai";

export const openai = new OpenAI({ apiKey: '-', baseURL: `http://${process.env.NEXT_PUBLIC_API_URL ?? "localhost"}:${process.env.NEXT_PUBLIC_API_PORT ?? "8011"}/${process.env.NEXT_PUBLIC_API_VERSION ?? "v1"}`, dangerouslyAllowBrowser: true });

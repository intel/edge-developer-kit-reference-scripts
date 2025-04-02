// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import { createOpenAI } from '@ai-sdk/openai';
import { type CoreMessage, StreamData, streamText } from 'ai';
import { type NextRequest } from 'next/server';

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type -- disable for route handler
export async function POST(req: NextRequest) {
    const { messages }: { messages: CoreMessage[] } = await req.json();
    const url = `http://${process.env.NEXT_PUBLIC_LLM_URL ?? "localhost"}/api`
    const openai = createOpenAI({
        baseURL: url,
        apiKey: "-",
        compatibility: "compatible"
    })

    let message = '';
    let wordCount = 0;
    let index = 0;
    const minimumWordCount = 10;
    const maxTokens = 512
    const temperature = 0.3
    const punctuations = ',.!?;:*';
    const data = new StreamData();

    const result = await streamText({
        model: openai(`${process.env.NEXT_PUBLIC_LLM_MODEL ?? "qwen2.5"}`),
        messages,
        maxTokens,
        temperature,
        headers: {
            rag: "ON"
        },
        onChunk({ chunk }) {
            if (chunk.type === 'text-delta') {
                message += chunk.textDelta;
                wordCount += chunk.textDelta.split(/\s+/).length - 1;
                if (punctuations.includes(chunk.textDelta) && wordCount > minimumWordCount) {
                    data.append({ index, message, processed: false });
                    message = '';
                    wordCount = 0;
                    index++;
                }
            }
        },
        onFinish() {
            if (message) {
                data.append({ index, message, processed: false });
                message = '';
                index++;
            }

            void data.close();
        }
    });
    return result.toDataStreamResponse({ data });
}
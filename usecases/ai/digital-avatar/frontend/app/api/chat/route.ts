// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import { CoreMessage, StreamData, streamText } from 'ai';
import { createOllama } from 'ollama-ai-provider';

export async function POST(req: Request) {
    const { messages }: { messages: CoreMessage[] } = await req.json();
    const ollama = createOllama({
        baseURL: `http://${process.env.NEXT_PUBLIC_LLM_URL}/api`,
    })

    let message = '';
    let wordCount = 0;
    let index = 0;
    const minimumWordCount = 10;
    const punctuations = ',.!?;:*';
    const data = new StreamData();

    const result = await streamText({
        model: ollama(`${process.env.NEXT_PUBLIC_LLM_MODEL ?? "qwen2.5"}`),
        messages,
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
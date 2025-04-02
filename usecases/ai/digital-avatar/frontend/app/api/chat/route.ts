// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import { createOpenAI } from '@ai-sdk/openai';
import { CoreMessage, StreamData, streamText } from 'ai';

export async function POST(req: Request) {
    const { messages, model }: { messages: CoreMessage[], model: string } = await req.json();
    const openai = createOpenAI({
        baseURL: `http://${process.env.NEXT_PUBLIC_LLM_URL ?? "localhost:8015"}/v1`,
        apiKey: "ollama",
    })

    let message = '';
    let wordCount = 0;
    let index = 0;
    const minimumWordCount = 5;
    const punctuations = ',.!?;:*';
    const data = new StreamData();

    const result = await streamText({
        model: openai(`${model ?? "qwen2.5"}`),
        messages,
        headers: {
            rag: "ON"
        },
        system: "You are a helpful assistant. Always reply in English. Summarize content to be 100 words",
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
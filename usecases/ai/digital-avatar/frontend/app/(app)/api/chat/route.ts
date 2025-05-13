// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import { createOllama } from 'ollama-ai-provider';
import { CoreMessage, createDataStreamResponse, streamText } from 'ai';

export async function POST(req: Request) {
    const { messages, model }: { messages: CoreMessage[], model: string } = await req.json();
    const ollama = createOllama({
        baseURL: `http://${process.env.NEXT_PUBLIC_LLM_URL ?? "localhost:8015"}/v1`,
    })

    let message = '';
    let wordCount = 0;
    let index = 0;
    const minimumWordCount = 5;
    const punctuations = ',.!?;:*';

    const startTime: number = Date.now();
    let firstTokenTime: number | null = null;

    return createDataStreamResponse({
        execute: dataStream => {
            const result = streamText({
                model: ollama(`${model ?? "qwen2.5"}`),
                messages,
                headers: {
                    include_usage: "true",
                },
                onChunk({ chunk }) {
                    if (chunk.type === 'text-delta') {
                        if (firstTokenTime === null) {
                            firstTokenTime = Date.now();
                        }

                        message += chunk.textDelta;
                        wordCount += chunk.textDelta.split(/\s+/).length - 1;
                        if (punctuations.includes(chunk.textDelta) && wordCount > minimumWordCount) {
                            dataStream.writeData({ index, message, processed: false })
                            message = '';
                            wordCount = 0;
                            index++;
                        }
                    }
                },
                onFinish(data) {
                    if (message) {
                        dataStream.writeData({ index, message, processed: false });
                        message = '';
                        index++;
                    }

                    if (startTime !== null && firstTokenTime !== null) {
                        const stopTime = Date.now();
                        const totalNextTokenLatency = (stopTime - firstTokenTime) / 1000;
                        const ttft = (firstTokenTime - startTime) / 1000;
                        dataStream.writeMessageAnnotation({
                            ttft,
                            totalNextTokenLatency,
                            usage: data.usage,
                        });
                    }
                }
            });
            result.mergeIntoDataStream(dataStream);
        },
        onError: error => {
            // Error messages are masked by default for security reasons.
            // If you want to expose the error message to the client, you can do so here:
            console.log(error)
            return error instanceof Error ? error.message : String(error);
        },
    })
}
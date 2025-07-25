// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import { createOpenAI } from '@ai-sdk/openai';
import { type CoreMessage, StreamData, streamText } from 'ai';
import { type NextRequest } from 'next/server';

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type -- disable for route handler
export async function POST(req: NextRequest) {
    const { messages, modelID, max_tokens: maxTokens, temperature, conversationCount, rag, systemPrompt }: { messages: CoreMessage[], modelID: string, max_tokens: number, temperature: number, conversationCount: number, rag: boolean, systemPrompt: string } = await req.json();
    const url = `http://${process.env.NEXT_PUBLIC_LLM_API_URL ?? "localhost"}:${process.env.NEXT_PUBLIC_LLM_API_PORT ?? "8011"}`
    const apiVersion = process.env.NEXT_PUBLIC_API_VERSION ?? "v1"
    const baseURL = new URL(`${apiVersion}/`, url).toString()
    const openai = createOpenAI({
        baseURL,
        apiKey: "-",
        compatibility: "compatible"
    })

    let conversationMessages = messages

    if (conversationCount >= 0 && conversationCount * 2 < messages.length) {
        conversationMessages = messages.slice(-(conversationCount * 2 + 1))
    }

    if (!messages.some((message) => message.role === 'system')) {
        if (systemPrompt) {
            conversationMessages = [{ role: 'system', content: systemPrompt }, ...messages];
        }
    }

    let message = '';
    const punctuations = ',.!?;:';
    const data = new StreamData()
    const result = streamText({
        model: openai(modelID),
        messages: conversationMessages,
        maxTokens,
        temperature,
        headers: {
            rag: rag ? "ON" : "OFF"
        },
        onChunk({ chunk }) {
            if (chunk.type === 'text-delta') {
                message += chunk.textDelta;
                if (punctuations.includes(chunk.textDelta)) {
                    data.append({ message, processed: false });
                    message = '';
                }
            }

        },
        onFinish() {
            if (message) {
                data.append({ message, processed: false });
                message = '';
            }
            void data.close();
        }
    });
    return result.toDataStreamResponse({ data });
}
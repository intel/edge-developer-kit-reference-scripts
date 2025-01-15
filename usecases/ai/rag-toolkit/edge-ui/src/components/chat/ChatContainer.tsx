// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"
import { Stack } from "@mui/material";
import React, { useEffect, useState } from "react";
import ChatHistory from "./ChatHistory";
import { useGetModelID } from "@/hooks/api-hooks/use-chat-api";
import { useChat } from 'ai/react'
import ChatTextField from "./ChatTextField";
import ChatToolbar from "./ChatToolbar";
import useAudioPlayer from "@/hooks/use-audio-player";
import { enqueueSnackbar } from "notistack";
import { useRecordAudio } from "@/hooks/use-record-audio";

interface StreamData {
    message: string,
    processed: boolean
}

export default function ChatContainer(): React.JSX.Element {
    const [maxTokens, setMaxTokens] = useState(512)
    const [temperature, setTemperature] = useState(0.3)
    const [rag, setRag] = useState(false)
    const [enableAudio, setEnableAudio] = useState(true)
    const [conversationCount, setConversationCount] = useState(0)
    const { data: modelID, isError, isLoading: isModelLoading } = useGetModelID();
    const { recording, speechProcessing, text, startRecording, stopRecording, clearText, languages, updateLanguage, language } = useRecordAudio();
    const { addQueue, clearAudioQueue, isPlaying } = useAudioPlayer();
    const [systemPrompt, setSystemPrompt] = useState<string | null>(null);
    const [functionTools, setFunctionTools] = useState<string | null>(null);

    useEffect(() => {
        const storedPrompt = localStorage.getItem('systemPrompt');
        if (storedPrompt) {
            setSystemPrompt(storedPrompt);
        }
    }, []);

    useEffect(() => {
        const storedTools = localStorage.getItem('functionTools');
        if (storedTools) {
            setFunctionTools(storedTools);
        }
    }, []);

    const { messages, input, setInput, append, isLoading: isGettingResponse, setMessages, data, stop } = useChat({
        body: {
            modelID, max_tokens: maxTokens, temperature, conversationCount, rag, systemPrompt, functionTools
        }
    });

    const updateMaxTokens = (num: number): void => {
        setMaxTokens(num)
    }

    const updateTemperature = (temp: number): void => {
        setTemperature(temp)
    }

    const updateConversationCount = (count: number): void => {
        setConversationCount(count)
    }


    useEffect(() => {
        if (data && enableAudio) {
            const streamData: (StreamData | null)[] = data as (StreamData | null)[]
            streamData.forEach((d) => {
                if (d && !d.processed) {
                    d.processed = true
                    addQueue(d.message.trim())
                }
            })
        }

    }, [addQueue, data, enableAudio])

    // Update messages once stt is done processing audio
    useEffect(() => {
        if (!recording && !speechProcessing && text.type !== "none") {
            if (text.type === "success") {
                if (text.result) {
                    void append({ role: "user", content: text.result })
                } else {
                    enqueueSnackbar('No text detected', { variant: 'warning' });
                }
            } else {
                enqueueSnackbar(text.result ?? "Error communicating with server", { variant: 'error' });
            }
            clearText()
        }
    }, [recording, text, speechProcessing, clearText, append]);

    useEffect(() => {
        clearAudioQueue()
        // eslint-disable-next-line react-hooks/exhaustive-deps -- clean up audio queue before starting
    }, [])

    const updateAudio = (): void => {
        setEnableAudio(prev => !prev)
    }

    const updateRag = (): void => {
        setRag(prev => !prev)
    }


    return (
        <Stack
            display="flex"
            flexDirection="column"
            height="max(85vh, 450px)"
            sx={{ justifyContent: "center" }}
        >
            <ChatHistory isError={isError} isLoading={isModelLoading} messages={messages} isGettingResponse={isGettingResponse} />
            <Stack
                sx={{ border: "1px solid black", p: ".5rem", pb: 0, borderRadius: "10px", mb: "1rem" }}
            >
                <ChatToolbar
                    conversationCount={conversationCount} updateConversationCount={updateConversationCount}
                    rag={rag} updateRag={updateRag}
                    temperature={temperature} updateTemperature={updateTemperature}
                    language={language} languages={languages} updateLanguage={updateLanguage}
                    enableAudio={enableAudio} updateAudio={updateAudio}
                    maxTokens={maxTokens} updateMaxTokens={updateMaxTokens}
                />
                <Stack
                    direction="row"
                    spacing={1}
                    alignItems="flex-start"
                    justifyContent="center"
                >
                    <ChatTextField
                        modelID={modelID} isError={isError} isModelLoading={isModelLoading} isGettingResponse={isGettingResponse}
                        messages={messages} setMessages={setMessages}
                        input={input} setInput={setInput}
                        append={append} handleStop={stop}
                        recording={recording} speechProcessing={speechProcessing} isPlaying={isPlaying}
                        startRecording={startRecording} stopRecording={stopRecording} clearAudioQueue={clearAudioQueue}
                    />
                </Stack>
            </Stack>
        </Stack>
    )
}
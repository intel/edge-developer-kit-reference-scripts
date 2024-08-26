// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"
import { Stack } from "@mui/material";
import React, { useEffect, useState } from "react";
import { type Message } from "@/types/chat";
import ChatHistory from "./ChatHistory";
import ChatTextField from "./ChatTextField";
import { openai } from "@/lib/openai";
import { enqueueSnackbar } from "notistack";

export default function ChatContainer(): React.JSX.Element {
    const [messages, setMessages] = useState<Message[]>([]);
    const [isInit, setIsInit] = useState(true);
    const [isError, setIsError] = useState(false);
    const [selectedModel, setSelectedModel] = useState("");

    useEffect(() => {
        const fetchModels = async (): Promise<void> => {
            try {
                const response = await openai.models.list();
                const id = response.data[0].id
                setSelectedModel(id);
                setIsInit(false);
            } catch (error) {
                setIsError(true);
                enqueueSnackbar(
                    `Failed to fetch model id from inference services. Please check the connection.`,
                    {
                        variant: "error",
                    }
                );
            }
        };
        void fetchModels();
    }, []);

    return (
        <Stack
            display="flex"
            flexDirection="column"
            height="max(85vh, 450px)"
            sx={{ justifyContent: "center" }}
        >
            <ChatHistory isError={isError} isInit={isInit} messages={messages} />
            <ChatTextField isInit={isInit} isError={isError} selectedModel={selectedModel} messages={messages} setMessages={setMessages} />
        </Stack>
    )
}
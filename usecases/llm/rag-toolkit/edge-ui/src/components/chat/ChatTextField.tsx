// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import React from "react";
import { CircularProgress, IconButton, Stack, TextField, Tooltip } from "@mui/material";
import { enqueueSnackbar } from "notistack";
import { Box } from "@mui/system";
import { KeyboardVoice, Refresh, Send, Stop } from "@mui/icons-material";
import { type ChatRequestOptions, type CreateMessage, type Message } from "ai";

export default function ChatTextField({
    modelID, isError, isModelLoading, messages, input, setInput, append,
    isGettingResponse, setMessages, handleStop, speechProcessing,
    recording, startRecording, stopRecording, clearAudioQueue, isPlaying
}: {
    modelID?: string,
    isError: boolean,
    isModelLoading: boolean,
    messages: Message[],
    input: string,
    setInput: React.Dispatch<React.SetStateAction<string>>,
    append: (message: Message | CreateMessage, chatRequestOptions?: ChatRequestOptions) => Promise<string | null | undefined>,
    isGettingResponse: boolean,
    setMessages: (messages: Message[] | ((messages: Message[]) => Message[])) => void,
    handleStop: VoidFunction,
    recording: boolean,
    speechProcessing: boolean,
    startRecording: VoidFunction,
    stopRecording: VoidFunction,
    clearAudioQueue: VoidFunction,
    isPlaying: boolean
}): React.JSX.Element {

    const handleRefresh = (): void => {
        setMessages([]);
        setInput("");
    };

    const handleMicClick = (): void => {
        if (recording) {
            stopRecording();
        } else {
            startRecording();
        }
    };

    const handleStopChat = (): void => {
        handleStop()
        clearAudioQueue()
    }

    const handleEnter = async (event: React.KeyboardEvent<HTMLDivElement> | undefined): Promise<void> => {
        if (event?.key !== 'Enter' || isGettingResponse) {
            return;
        }
        await handleOnSend();
    };

    const handleOnSend = async (): Promise<void> => {
        if (!modelID) {
            enqueueSnackbar('Failed to get the model id from server.', { variant: 'error' });
            return;
        }
        clearAudioQueue()
        void append({ 'content': input, role: 'user' })
        setInput("")
    };

    return (

        <TextField
            fullWidth
            multiline
            rows={3}
            variant="standard"
            placeholder={isGettingResponse ? "Response generating..." : "Type your message here"}
            value={input}
            onChange={(event) => {
                setInput(event.target.value);
            }}
            onKeyDown={handleEnter}
            disabled={isGettingResponse}
            InputProps={{
                endAdornment: (
                    <Stack direction="row" spacing={1}>
                        {
                            isGettingResponse || isPlaying ?
                                <IconButton
                                    onClick={handleStopChat}
                                    color="error"
                                >
                                    <Tooltip title="Stop Chat" placement="top">
                                        <Stop />
                                    </Tooltip>
                                </IconButton>
                                :
                                messages.length >= 1 && (
                                    <IconButton
                                        onClick={handleRefresh}
                                        disabled={isGettingResponse || isPlaying}
                                        color="primary"
                                    >
                                        <Tooltip title="Refresh Chat" placement="top">
                                            <Refresh />
                                        </Tooltip>
                                    </IconButton>
                                )
                        }
                        {
                            speechProcessing ?
                                <Box sx={{ display: "flex", justifyContent: "center", alignItems: "center" }}>
                                    <CircularProgress size={25} />
                                </Box>
                                :
                                <Tooltip title={`${recording ? "Stop" : "Start"} Recording`} placement="top">
                                    <Box>
                                        <IconButton
                                            onClick={handleMicClick}
                                            color="primary"
                                            disabled={isPlaying || isGettingResponse || isError || isModelLoading}
                                        >
                                            {
                                                recording ?
                                                    <Stop color="error" />
                                                    :
                                                    <KeyboardVoice />
                                            }
                                        </IconButton>
                                    </Box>
                                </Tooltip>
                        }

                        <Tooltip title="Submit" placement="top">
                            <Box>
                                <IconButton
                                    type="submit"
                                    onClick={handleOnSend}
                                    disabled={isPlaying || isGettingResponse || isError || isModelLoading || recording || speechProcessing}
                                    color="primary"
                                >
                                    <Send />
                                </IconButton>
                            </Box>
                        </Tooltip>
                    </Stack>
                ),
            }}
        />
    )
}
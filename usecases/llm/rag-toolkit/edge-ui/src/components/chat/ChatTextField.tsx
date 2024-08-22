import { KeyboardVoice, Refresh, Send, Stop } from "@mui/icons-material";
import { Box, CircularProgress, IconButton, Stack, TextField, Tooltip } from "@mui/material";
import React, { useCallback, useEffect, useRef, useState } from "react";
import { enqueueSnackbar } from "notistack";
import { openai } from "@/lib/openai";
import { type Message } from "@/types/chat";
import { type Stream } from "openai/streaming";
import { type ChatCompletionChunk } from "openai/resources";
import { useRecordAudio } from "@/hooks/use-record-audio";
import useAudioPlayer from "@/hooks/use-audio-player";
import ChatToolbar from "./ChatToolbar";

export default function ChatTextField({
    isInit,
    isError,
    selectedModel,
    messages,
    setMessages
}: { isInit: boolean, isError: boolean, selectedModel: string, messages: Message[], setMessages: React.Dispatch<React.SetStateAction<Message[]>> }): React.JSX.Element {

    const [input, setInput] = useState("");
    const [isLoading, setIsLoading] = useState(false);
    const textFieldRef = useRef(null);
    const { addQueue, clearAudioQueue } = useAudioPlayer();
    const { recording, speechProcessing, text, startRecording, stopRecording, clearText, languages, updateLanguage, language } = useRecordAudio();
    const [enableAudio, setEnableAudio] = useState(true)
    const [temperature, setTemperature] = useState(70)
    const [rag, setRag] = useState(false)
    const [conversationCount, setConversationCount] = useState(1)

    const submitMessage = useCallback(async (message: string): Promise<void> => {
        if (!selectedModel) return;

        const userMessage: Message = { role: "user", content: message, status: "pending" };
        const assistantMessage: Message = { role: "assistant", content: "", status: "pending" };
        setMessages((prevMessages) => [...prevMessages, userMessage, assistantMessage]);
        setInput("");
        setIsLoading(true);

        try {
            let conversationMessages = messages
            if (conversationCount * 2 > 0 && conversationCount * 2 < messages.length) {
                conversationMessages = messages.slice(-conversationCount * 2)
            }
            const chatParams = {
                model: selectedModel,
                messages: [...conversationMessages, userMessage],
                temperature,
                stream: true,
                rag,
            }
            const stream = await openai.chat.completions.create(chatParams);

            let responseMessage = ""

            for await (const chunk of stream as Stream<ChatCompletionChunk>) {
                const content = chunk.choices[0]?.delta?.content || "";
                assistantMessage.content += content;
                setMessages((prevMessages) => [
                    ...prevMessages.slice(0, -1),
                    { ...assistantMessage, status: "success" },
                ]);

                if (enableAudio) {
                    responseMessage += content
                    const sentences = responseMessage.split(/(?:[.!?])/);
                    for (let i = 0; i < sentences.length - 1; i += 2) {
                        const sentence = sentences[i] + sentences[i + 1];
                        addQueue(sentence.trim())
                    }

                    responseMessage = sentences[sentences.length - 1];
                }
            }
            if (enableAudio && responseMessage.trim()) {
                addQueue(responseMessage.trim())
            }
        } catch (error) {
            console.error("Error:", error);
            // Handle error (e.g., show an error message to the user)
        } finally {
            setIsLoading(false);
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps -- don't need setmessages
    }, [input, messages, selectedModel, conversationCount])

    // Update messages once stt is done processing audio
    useEffect(() => {
        if (!recording && !speechProcessing && text.type !== "none") {
            if (text.type === "success") {
                if (text.result) {
                    void submitMessage(text.result)
                } else {
                    enqueueSnackbar('No text detected', { variant: 'warning' });
                }
            } else {
                enqueueSnackbar(text.result ?? "Error communicating with server", { variant: 'error' });
            }
            clearText()
        }
    }, [recording, text, speechProcessing, clearText, submitMessage]);

    useEffect(() => {
        clearAudioQueue()
        // eslint-disable-next-line react-hooks/exhaustive-deps -- clean up audio queue before starting
    }, [])

    const handleSubmit = (e?: React.FormEvent<HTMLFormElement>): void => {
        if (e)
            e.preventDefault();
        if (!input.trim())
            return
        void submitMessage(input)
    };

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

    const handleKeyDown = (e: React.KeyboardEvent<HTMLDivElement>): void => {
        if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            if (!input.trim())
                return
            void submitMessage(input);
        }
    };

    const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>): void => {
        setInput(e.target.value);
        // Adjust textarea height
        e.target.style.height = "auto";
        e.target.style.height = `${e.target.scrollHeight}px`;
    };

    const updateAudio = (): void => {
        setEnableAudio(prev => !prev)
    }

    const updateTemperature = (temp: number): void => {
        setTemperature(temp)
    }

    const updateRag = (): void => {
        setRag(prev => !prev)
    }

    const updateConversationCount = (count: number): void => {
        setConversationCount(count)
    }

    return (
        <Stack
            sx={{ border: "1px solid black", p: ".5rem", pb: 0, borderRadius: "10px", mb: "1rem" }}
        >
            <ChatToolbar conversationCount={conversationCount} updateConversationCount={updateConversationCount} rag={rag} updateRag={updateRag} temperature={temperature} updateTemperature={updateTemperature} language={language} languages={languages} updateLanguage={updateLanguage} enableAudio={enableAudio} updateAudio={updateAudio} />
            <Box component="form" onSubmit={e => { handleSubmit(e); }}>
                <Stack
                    direction="row"
                    spacing={1}
                    alignItems="flex-start"
                    justifyContent="center"
                >
                    <TextField
                        fullWidth
                        multiline
                        rows={3}
                        variant="standard"
                        placeholder="Type your message..."
                        value={input}
                        onChange={e => { handleInputChange(e); }}
                        onKeyDown={e => { handleKeyDown(e); }}
                        disabled={isLoading}
                        InputProps={{
                            endAdornment: (
                                <Stack direction="row" spacing={1}>
                                    {messages.length >= 1 && (
                                        <IconButton
                                            onClick={handleRefresh}
                                            disabled={isLoading}
                                            color="primary"
                                        >
                                            <Tooltip title="Refresh Chat" placement="top">
                                                <Refresh />
                                            </Tooltip>
                                        </IconButton>
                                    )}
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
                                                        disabled={isLoading || isError || isInit}
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
                                                disabled={isLoading || isError || isInit || recording || speechProcessing}
                                                color="primary"
                                            >
                                                <Send />
                                            </IconButton>
                                        </Box>
                                    </Tooltip>
                                </Stack>
                            ),
                        }}
                        inputRef={textFieldRef}
                    />
                </Stack>
            </Box>
        </Stack>

    )
}
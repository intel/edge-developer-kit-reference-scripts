import { type Message } from "@/types/chat";
import { Avatar, Box, CircularProgress, Paper, Stack, Typography } from "@mui/material";
import React, { useEffect, useRef } from "react";
import Markdown from "../common/markdown";

export default function ChatHistory({ isInit, isError, messages }: { isError: boolean, isInit: boolean, messages: Message[] }): React.JSX.Element {
    const messagesEndRef = useRef<HTMLDivElement>(null);
    const scrollToBottom = (): void => {
        messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    };

    useEffect(scrollToBottom, [messages]);

    return (
        <Box
            flexGrow={1}
            overflow="auto"
            sx={{ border: 1, borderRadius: 2, mt: 2, mb: 2 }}
        >
            {
                isInit ?
                    <Stack gap="1rem" height="100%" justifyContent="center" alignItems="center">
                        {
                            isError ?
                                <>
                                    <Typography variant="h6">Oops, model fail to be fetched.</Typography>
                                    <Typography variant="h6">Please refresh the page to try again</Typography>
                                </>
                                :
                                <>
                                    <Typography variant="h6">Model Loading...</Typography>
                                    <CircularProgress />
                                </>
                        }
                    </Stack>
                    :
                    messages.length < 1 ?
                        <Stack gap="1rem" height="100%" justifyContent="center" alignItems="center">
                            <Typography variant="h6">Start by typing some message to me below.</Typography>
                        </Stack>
                        :
                        messages.map((message, index) => (
                            <Box
                                key={index}
                                sx={theme => ({
                                    justifyContent:
                                        message.role === "user" ? "flex-end" : "flex-start",
                                    display: "flex",
                                    padding: theme.spacing(2),
                                })}
                            >
                                <Paper sx={theme => ({
                                    padding: theme.spacing(2),
                                    maxWidth: "70%",
                                    borderRadius: "25px",
                                    backgroundColor: message.role === "user"
                                        ? theme.palette.primary.main
                                        : theme.palette.grey[300],
                                    color: message.role === "user"
                                        ? theme.palette.primary.contrastText
                                        : theme.palette.text.primary,
                                })} elevation={1}>
                                    <Stack direction="row" spacing={2}>
                                        <Avatar
                                            sx={{
                                                mr: 2,
                                                mt: ".5rem",
                                                border: "1px solid black",
                                                bgcolor:
                                                    message.role === "user"
                                                        ? "white"
                                                        : "secondary.main",
                                                color: message.role === "user" ? "black" : "white"
                                            }}
                                        >
                                            {message.role === "user" ? "U" : "A"}
                                        </Avatar>
                                        <Markdown content={message.status === "pending" && message.role === "assistant" ? "Loading..." : message.content} />
                                    </Stack>
                                </Paper>
                            </Box>
                        ))
            }

            <div ref={messagesEndRef} />
        </Box>
    )
}
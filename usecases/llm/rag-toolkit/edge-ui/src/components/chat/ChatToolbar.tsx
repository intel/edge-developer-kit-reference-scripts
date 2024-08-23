import { AccessAlarm, AlarmOff, Language, Thermostat, VolumeOff, VolumeUp } from "@mui/icons-material";
import { Box, IconButton, Stack, Tooltip, Typography } from "@mui/material";
import React from "react";
import LanguagePopover from "./Popovers/LanguagePopover";
import { usePopover } from "@/hooks/use-popover";
import TemperaturePopover from "./Popovers/TemperaturePopover";
import { type LanguageProps } from "@/hooks/use-record-audio";
import ConversationHistoryPopover from "./Popovers/ConversationHistoryPopover";

export default function ChatToolbar({ rag, updateRag, conversationCount, updateConversationCount, temperature, updateTemperature, languages, language, updateLanguage, enableAudio, updateAudio }: {
    rag: boolean, updateRag: VoidFunction, temperature: number, updateTemperature: (temp: number) => void,
    conversationCount: number, updateConversationCount: (count: number) => void,
    languages: { name: string, value: string }[], language: LanguageProps, updateLanguage: (selectedLanguage: LanguageProps) => void,
    enableAudio: boolean, updateAudio: VoidFunction
}): React.JSX.Element {
    const languagePopover = usePopover<HTMLDivElement>()
    const temperaturePopover = usePopover<HTMLDivElement>()
    const conversationHistoryPopover = usePopover<HTMLDivElement>()

    return (
        <>
            <Stack direction="row" gap="1rem" alignItems="center">
                <Tooltip title={`Include ${conversationCount < 1 ? 'all' : conversationCount} conversation history`}>
                    <Box ref={conversationHistoryPopover.anchorRef}>
                        <IconButton onClick={conversationHistoryPopover.handleOpen}>
                            {
                                conversationCount < 1 ?
                                    <AlarmOff /> :
                                    <AccessAlarm />
                            }
                        </IconButton>
                    </Box>
                </Tooltip>

                <Tooltip title={enableAudio ? "Audio Enabled" : "Audio Disabled"}>
                    <Box>
                        <IconButton onClick={updateAudio}>
                            {
                                enableAudio ?
                                    <VolumeUp /> :
                                    <VolumeOff />
                            }
                        </IconButton>
                    </Box>
                </Tooltip>

                <Tooltip title={`Temperature: ${temperature} `}>
                    <Box ref={temperaturePopover.anchorRef}>
                        <IconButton onClick={temperaturePopover.handleOpen}>
                            <Thermostat />
                        </IconButton>
                    </Box>
                </Tooltip>

                <Tooltip title="RAG">
                    <Box>
                        <IconButton onClick={updateRag}>
                            <Typography sx={{
                                fontWeight: "bold",
                                position: 'relative',
                                display: 'inline-block',
                                '::after': rag ? "" : {
                                    content: '""',
                                    position: 'absolute',
                                    left: 0,
                                    right: 0,
                                    top: '50%',
                                    height: '2px', // Adjust the thickness of the strikethrough line
                                    backgroundColor: 'black', // Adjust the color of the strikethrough line
                                    transform: 'rotate(-15deg)', // Adjust the angle of inclination
                                },
                            }} variant="body2">RAG</Typography>
                        </IconButton>
                    </Box>
                </Tooltip>

                <Tooltip title="Language">
                    <Box ref={languagePopover.anchorRef}>
                        <IconButton onClick={languagePopover.handleOpen}>
                            <Language />
                        </IconButton>
                    </Box>
                </Tooltip>

            </Stack>
            <LanguagePopover language={language} languages={languages} updateLanguage={updateLanguage} open={languagePopover.open} anchorEl={languagePopover.anchorRef.current} handleClose={languagePopover.handleClose} />
            <TemperaturePopover temperature={temperature} updateTemperature={updateTemperature} open={temperaturePopover.open} anchorEl={temperaturePopover.anchorRef.current} handleClose={temperaturePopover.handleClose} />
            <ConversationHistoryPopover count={conversationCount} updateCount={updateConversationCount} open={conversationHistoryPopover.open} anchorEl={conversationHistoryPopover.anchorRef.current} handleClose={conversationHistoryPopover.handleClose} />
        </>

    )
}
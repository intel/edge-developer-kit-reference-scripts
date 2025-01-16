// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

'use client';

import { Stack, Typography, Accordion, AccordionSummary, AccordionDetails, TextField, Button } from "@mui/material";
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import React, { useState, useEffect } from "react";

const sections = [
    { title: "System Prompts", content: "Content for System Prompts." },
    { title: "Tools", content: "Content for Tools." }
];

export default function ChatPage(): React.JSX.Element {
    const [expanded, setExpanded] = useState<string | false>('System Prompts');
    const [systemPrompt, setSystemPrompt] = useState<string>("You are a helpful assistant. Always reply in English.");
    const [tools, setTools] = useState<string>('');
    const [isChanged, setIsChanged] = useState<boolean>(false);
    const [isToolsChanged, setIsToolsChanged] = useState<boolean>(false);
    const [isToolsValidJson, setIsToolsValidJson] = useState<boolean>(true);

    useEffect(() => {
        const storedPrompt = localStorage.getItem('systemPrompt');
        if (storedPrompt) {
            setSystemPrompt(storedPrompt);
        }
    }, []);
    
    useEffect(() => {
        const storedTools = localStorage.getItem('functionTools');
        if (storedTools) {
            setTools(storedTools);
        }
    }, []);

    const handleChange = (panel: string) => (event: React.SyntheticEvent, isExpanded: boolean): void => {
        setExpanded(isExpanded ? panel : false);
    };

    const handleSystemPromptChange = (e: React.ChangeEvent<HTMLInputElement>): void => {
        const newPrompt = e.target.value;
        setSystemPrompt(newPrompt);
        setIsChanged(true);
    };

    const handleToolsChange = (e: React.ChangeEvent<HTMLInputElement>): void => {
        const newTools = e.target.value;
        setTools(newTools);
        setIsToolsChanged(true);
        try {
            JSON.parse(newTools);
            setIsToolsValidJson(true);
        } catch {
            setIsToolsValidJson(false);
        }
    };

    const handleSavePrompt = () => {
        localStorage.setItem('systemPrompt', systemPrompt);
        setIsChanged(false);
    };

    const handleSaveTools = () => {
        localStorage.setItem('functionTools', tools);
        setIsToolsChanged(false);
    };

    return (
        <Stack spacing={2} sx={{ flex: "1 1 auto", mt: 3, p: 2, bgcolor: 'background.paper', borderRadius: 1 }}>
            <Typography variant="h4" gutterBottom>Settings</Typography>
            {sections.map((section, index) => (
                <Accordion 
                    key={index} 
                    expanded={expanded === section.title} 
                    onChange={handleChange(section.title)}
                    sx={{ boxShadow: 3 }}
                >
                    <AccordionSummary expandIcon={<ExpandMoreIcon />}>
                        <Typography variant="h6">{section.title}</Typography>
                    </AccordionSummary>
                    <AccordionDetails>
                        {section.title === "System Prompts" && (
                            <Stack spacing={2} sx={{ width: '100%' }}>
                                <TextField
                                    label="System Prompt"
                                    multiline
                                    rows={8}
                                    variant="outlined"
                                    fullWidth
                                    value={systemPrompt}
                                    onChange={handleSystemPromptChange}
                                />
                                <Button 
                                    variant="contained" 
                                    color="primary" 
                                    onClick={handleSavePrompt} 
                                    disabled={!isChanged}
                                >
                                    Save
                                </Button>
                            </Stack>
                        )}
                        {section.title === "Tools" && (
                            <Stack spacing={2} sx={{ width: '100%' }}>
                                <TextField
                                    label="Tools"
                                    multiline
                                    rows={8}
                                    variant="outlined"
                                    fullWidth
                                    value={tools}
                                    onChange={handleToolsChange}
                                    disabled
                                    error={!isToolsValidJson}
                                    helperText={!isToolsValidJson ? "Invalid JSON" : ""}
                                />
                                <Button 
                                    variant="contained" 
                                    color="primary" 
                                    onClick={handleSaveTools} 
                                    disabled={!isToolsChanged || !isToolsValidJson}
                                >
                                    Save
                                </Button>
                            </Stack>
                        )}
                    </AccordionDetails>
                </Accordion>
            ))}
        </Stack>
    )
}
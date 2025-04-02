// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import { Settings } from 'lucide-react'
import { useState } from 'react'

import { Button } from "@/components/ui/button"

import Chatbox from './Chatbox'
import { ISettings, SettingsDialog } from './settings/SettingsDialog'

export default function Chat() {
    const [settings, setSettings] = useState<ISettings>({ gender: "female", expressionScale: 1.0, model: process.env.NEXT_PUBLIC_LLM_MODEL ?? "" })
    const [settingsDialogOpen, setSettingsDialogOpen] = useState(false)


    const updateDialogOpen = (open: boolean) => {
        setSettingsDialogOpen(open)
    }

    const updateSettings = (settings: ISettings) => {
        setSettings(settings)
    }

    return (
        <>
            <SettingsDialog open={settingsDialogOpen} setOpen={updateDialogOpen} updateValue={updateSettings} settingValues={settings} />
            <div className="p-4 flex justify-between items-center border-b">
                <h2 className="text-xl font-semibold">Chat</h2>
                <Button variant="outline" size="icon" onClick={() => updateDialogOpen(true)}>
                    <Settings />
                </Button>
            </div>
            <Chatbox settings={settings} />
        </>
    )
}
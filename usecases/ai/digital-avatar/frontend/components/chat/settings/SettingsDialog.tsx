// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"


import { useState } from "react"

import { Button } from "@/components/ui/button"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { cn } from "@/lib/utils"

import { LLMModelsSelect } from "./LLMModelsSelect"
import { Slider } from "../../ui/slider"

export interface ISettings {
    gender: string
    expressionScale: number,
    model: string
}

export function SettingsDialog({ open, setOpen, settingValues, updateValue }: { open: boolean, setOpen: (open: boolean) => void, settingValues: ISettings, updateValue: ({ gender, expressionScale }: ISettings) => void }) {
    const [gender, setGender] = useState(settingValues.gender)
    const [expressionScale, setExpressionScale] = useState(1.0)

    const [modelsOpen, setModelsOpen] = useState(false)
    const [selectedModel, setSelectedModel] = useState(process.env.NEXT_PUBLIC_LLM_MODEL ?? "")

    const handleSubmit = () => {
        updateValue({ gender, expressionScale, model: selectedModel })
        setOpen(false)
    }

    const updateModelsOpen = (open: boolean) => {
        setModelsOpen(open)
    }

    const updateSelectedModel = (model: string) => {
        setSelectedModel(model)
    }

    return (
        <Dialog open={open} onOpenChange={setOpen}>
            <DialogContent className="sm:max-w-[425px]">
                <DialogHeader>
                    <DialogTitle>Settings</DialogTitle>
                    <DialogDescription>Adjust your settings here. Click save when you&apos;re done.</DialogDescription>
                </DialogHeader>
                <div className="grid grid-cols-4 items-center gap-4">
                    <Label htmlFor="gender" className="text-right">
                        LLM Model
                    </Label>
                    <LLMModelsSelect open={modelsOpen} updateOpen={updateModelsOpen} value={selectedModel} updateValue={updateSelectedModel} />
                </div>
                <div className="grid gap-4 py-4">
                    <div className="grid grid-cols-4 items-center gap-4">
                        <Label htmlFor="gender" className="text-right">
                            TTS Gender
                        </Label>
                        <Select onValueChange={(value) => setGender(value)} defaultValue={gender}>
                            <SelectTrigger className="col-span-3">
                                <SelectValue placeholder="Select gender" />
                            </SelectTrigger>
                            <SelectContent>
                                <SelectItem value="male">Male</SelectItem>
                                <SelectItem value="female">Female</SelectItem>
                            </SelectContent>
                        </Select>
                    </div>
                    <div className="grid grid-cols-4 items-center gap-4">
                        <Label htmlFor="gender" className="text-right">
                            Expression Scale
                        </Label>
                        <div className="col-span-3 flex gap-4 space-between">
                            <Slider
                                max={1.0}
                                step={0.1}
                                className={cn("w-[85%]")}
                                // defaultValue={[1.0]}
                                value={[expressionScale]}
                                onValueChange={(value) => setExpressionScale(value[0])}
                            />
                            <div>
                                {expressionScale}
                            </div>
                        </div>
                    </div>
                </div>
                <DialogFooter>
                    <Button onClick={handleSubmit}>Save changes</Button>
                </DialogFooter>
            </DialogContent>
        </Dialog >
    )
}


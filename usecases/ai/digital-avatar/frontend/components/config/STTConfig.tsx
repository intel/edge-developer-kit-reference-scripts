"use client"

import {  Mic } from "lucide-react"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { DenoiseSTTConfigApiResponse, Language, SelectedPipelineConfig, STTModel } from "@/types/config"
import { ConfigSection } from "./ConfigSection"
import { SelectSkeleton } from "./InputSkeletons"

export default function STTConfig({ 
  config,
    handleConfigChange 
  } : { 
  config?: DenoiseSTTConfigApiResponse
  handleConfigChange: <K extends keyof SelectedPipelineConfig, T extends keyof SelectedPipelineConfig[K]>(
    section: K,
    key: T,
    value: SelectedPipelineConfig[K][T]
  ) => void 
}) {
  return (
    <ConfigSection
        title="Speech-to-Text Configuration"
        icon={<Mic className="h-5 w-5" />}
      >
        <div className="space-y-4">
          {config ? (
            <>
              <div className="space-y-2">
                <Label htmlFor="stt_device">Device</Label>
                <Select 
                  value={config.selected_config.stt_device}
                  onValueChange={(value) => handleConfigChange("denoiseStt", "stt_device", value)}
                >
                  <SelectTrigger id="stt_device">
                    <SelectValue placeholder="Select device" />
                  </SelectTrigger>
                  <SelectContent>
                    {config.devices.map(option => (
                      <SelectItem key={`stt-${option.value}`} value={option.value}>
                        {option.value} | {option.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label htmlFor="stt-model">Model</Label>
                <Select 
                  value={config.selected_config.stt_model}
                  onValueChange={(value) => handleConfigChange("denoiseStt", "stt_model", value as STTModel)}
                >
                  <SelectTrigger id="stt-model">
                    <SelectValue placeholder="Select model" />
                  </SelectTrigger>
                  <SelectContent>
                    {config.stt_models.map(option => (
                      <SelectItem key={option} value={option}>
                        {option}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label htmlFor="stt-language">Language</Label>
                <Select 
                  value={config.selected_config.language}
                  onValueChange={(value) => handleConfigChange("denoiseStt", "language", value as Language)}
                >
                  <SelectTrigger id="stt-language">
                    <SelectValue placeholder="Select language" />
                  </SelectTrigger>
                  <SelectContent>
                    {config.language.map(option => (
                      <SelectItem key={option} value={option}>
                        {option}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </>
          ) : (
            <>
              <SelectSkeleton />
              <SelectSkeleton />
              <SelectSkeleton />
            </>
          )}
        </div>
      </ConfigSection>
  )
}
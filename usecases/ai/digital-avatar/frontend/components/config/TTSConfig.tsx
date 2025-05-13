"use client"

import { Headphones } from "lucide-react"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { SelectedPipelineConfig, Speaker, TTSConfigApiResponse } from "@/types/config"
import { ConfigSection } from "./ConfigSection"
import SliderControl from "./SliderControl"
import { SelectSkeleton, SliderSkeleton } from "./InputSkeletons"

export default function TTSConfig({ 
  config,
  handleConfigChange 
} : { 
  config?: TTSConfigApiResponse
  handleConfigChange: <K extends keyof SelectedPipelineConfig, T extends keyof SelectedPipelineConfig[K]>(
    section: K,
    key: T,
    value: SelectedPipelineConfig[K][T]
  ) => void 
}) {
  return (
    <ConfigSection
      title="Text-to-Speech Configuration"
      icon={<Headphones className="h-5 w-5" />}
    >
      <div className="space-y-4">
        {config ? (
          <>
            <div className="space-y-2">
              <Label htmlFor="tts-device">Device</Label>
              <Select 
                value={config.selected_config.device}
                onValueChange={(value) => handleConfigChange("tts", "device", value)}
              >
                <SelectTrigger id="tts-device">
                  <SelectValue placeholder="Select device" />
                </SelectTrigger>
                <SelectContent>
                  {config.devices.map(option => (
                    <SelectItem key={`tts-${option}`} value={option}>
                      {option}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="tts-gender">Gender</Label>
              <Select 
                value={config.selected_config.speaker}
                onValueChange={(value) => handleConfigChange("tts", "speaker", value as Speaker)}
              >
                <SelectTrigger id="tts-gender">
                  <SelectValue placeholder="Select gender" />
                </SelectTrigger>
                <SelectContent>
                  {config.speaker.map(option => (
                    <SelectItem key={`tts-${option}`} value={option}>
                      {option}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* <div className="space-y-2">
              <Label htmlFor="tts-model">Model</Label>
              <Select 
                value={config.selected_config.tts.model}
                onValueChange={(value) => handleConfigChange("tts", "model", value)}
              >
                <SelectTrigger id="tts-model">
                  <SelectValue placeholder="Select model" />
                </SelectTrigger>
                <SelectContent>
                  {[
                    {value: "piper", label: "Piper"},
                    {value: "melo-tts", label: "MeloTTS"},
                  ].map(option => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div> */}

            <SliderControl
              id="tts-speed"
              label="Speed"
              value={config.selected_config.speed}
              min={0.5}
              max={2.0}
              step={0.1}
              valueLabels={["0.5x", "1.0x", "1.5x", "2.0x"]}
              onChange={(value) => handleConfigChange("tts", "speed", value)}
            />
          </>
        ) : (
          <>
            <SelectSkeleton />
            <SliderSkeleton />
          </>
        )}
      </div>
    </ConfigSection>
  )
}
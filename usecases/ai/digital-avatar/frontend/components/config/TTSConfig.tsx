"use client"

import { Headphones } from "lucide-react"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { SelectedPipelineConfig, TTSConfigApiResponse, TTSLanguage } from "@/types/config"
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
              <Label htmlFor="tts-language">Language</Label>
              <Select 
                value={config.selected_config.language}
                onValueChange={(value) => handleConfigChange("tts", "language", value)}
              >
                <SelectTrigger id="tts-language">
                  <SelectValue placeholder="Select language" />
                </SelectTrigger>
                <SelectContent>
                  {Object.keys(config.speakers).map(option => (
                    <SelectItem key={`tts-${option}`} value={option}>
                      {TTSLanguage[option as keyof typeof TTSLanguage]}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="tts-speaker">Speaker</Label>
              <Select 
                value={config.selected_config.speaker}
                onValueChange={(value) => handleConfigChange("tts", "speaker", value)}
              >
                <SelectTrigger id="tts-speaker">
                  <SelectValue placeholder="Select speaker" />
                </SelectTrigger>
                <SelectContent>
                  {config.speakers[config.selected_config.language].map(option => (
                    <SelectItem key={`tts-${option.name}`} value={option.name}>
                      {option.name} ({option.gender})
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

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
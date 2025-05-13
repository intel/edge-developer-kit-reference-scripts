"use client"

import { Headphones } from "lucide-react"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"
import { DenoiseModel, DenoiseModelPrecision, DenoiseSTTConfigApiResponse, SelectedPipelineConfig } from "@/types/config"
import { ConfigSection } from "./ConfigSection"
import { SelectSkeleton, RadioGroupSkeleton } from "./InputSkeletons"

export default function DenoiseConfig({ 
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
      title="Denoise Configuration"
      icon={<Headphones className="h-5 w-5" />}
    >
      <div className="space-y-4">
        {config ? (
          <>
            <div className="space-y-2">
              <Label htmlFor="denoise_device">Device</Label>
              <Select 
                value={config.selected_config.denoise_device}
                onValueChange={(value) => handleConfigChange("denoiseStt", "denoise_device", value)}
              >
                <SelectTrigger id="denoise_device">
                  <SelectValue placeholder="Select device" />
                </SelectTrigger>
                <SelectContent>
                  {config.devices.map(option => (
                    <SelectItem key={`denoise-${option.value}`} value={option.value}>
                      {option.value} | {option.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="denoise_model">Model</Label>
              <Select 
                value={config.selected_config.denoise_model}
                onValueChange={(value) => handleConfigChange("denoiseStt", "denoise_model", value as DenoiseModel)}
              >
                <SelectTrigger id="denoise_model">
                  <SelectValue placeholder="Select model" />
                </SelectTrigger>
                <SelectContent>
                  {config.denoise_models.map(option => (
                    <SelectItem key={option} value={option}>
                      {option}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label>Precision</Label>
              <RadioGroup 
                value={config.selected_config.denoise_model_precision}
                onValueChange={(value) => handleConfigChange("denoiseStt", "denoise_model_precision", value as DenoiseModelPrecision)}
                className="flex space-x-4"
              >
                {config.denoise_model_precisions.map(option => (
                  <div key={`denoise-${option}`} className="flex items-center space-x-2">
                    <RadioGroupItem value={option} id={`denoise-${option}`} />
                    <Label htmlFor={`denoise-${option}`}>{option}</Label>
                  </div>
                ))}
              </RadioGroup>
            </div>
          </>
        ) : (
          <>
            <SelectSkeleton />
            <SelectSkeleton />
            <RadioGroupSkeleton />
          </>
        )}
      </div>
    </ConfigSection>
  )
}
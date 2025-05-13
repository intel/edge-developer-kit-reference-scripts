"use client"

import { User } from "lucide-react"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Switch } from "@/components/ui/switch"
import { LipsyncConfigApiResponse, LipsyncModel, SelectedPipelineConfig, EnhancerModel } from "@/types/config"
import { ConfigSection } from "./ConfigSection"
import { SelectSkeleton, SwitchSkeleton } from "./InputSkeletons"

export default function LipsyncConfig({ 
  config,
  handleConfigChange 
} : { 
  config?: LipsyncConfigApiResponse
  handleConfigChange: <K extends keyof SelectedPipelineConfig, T extends keyof SelectedPipelineConfig[K]>(
    section: K,
    key: T,
    value: SelectedPipelineConfig[K][T]
  ) => void 
}) {
  return (
    <ConfigSection
      title="Lipsync Configuration"
      icon={<User className="h-5 w-5" />}
    >
      {config ? (
        <>
          <div className="space-y-2">
            <Label htmlFor="lipsync-device">Device</Label>
            <Select 
              value={config.selected_config.lipsync_device}
              onValueChange={(value) => handleConfigChange("lipsync", "lipsync_device", value)}
            >
              <SelectTrigger id="lipsync-device">
                <SelectValue placeholder="Select device" />
              </SelectTrigger>
              <SelectContent>
                {config.devices.lipsync_device.map(option => (
                  <SelectItem key={`lipsync-${option.value}`} value={option.value}>
                    {option.value} | {option.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label htmlFor="lipsync-model">Model</Label>
            <Select 
              value={config.selected_config.lipsync_model}
              onValueChange={(value) => handleConfigChange("lipsync", "lipsync_model", value as LipsyncModel)}
            >
              <SelectTrigger id="lipsync-model">
                <SelectValue placeholder="Select model" />
              </SelectTrigger>
              <SelectContent>
                {config.lipsync_models.map(option => (
                  <SelectItem key={option} value={option}>
                    {option}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="flex items-center space-x-2">
            <Switch 
              id="use-enhancer" 
              checked={config.selected_config.use_enhancer} 
              onCheckedChange={(checked) => handleConfigChange("lipsync", "use_enhancer", checked)} 
            />
            <Label htmlFor="use-enhancer">Use Enhancer</Label>
          </div>
          
          {config.selected_config.use_enhancer && (
            <>
              <div className="relative text-center text-sm after:absolute after:inset-0 after:top-1/2 after:z-0 after:flex after:items-center after:border-t after:border-border">
                <span className="relative z-10 bg-background px-2 text-muted-foreground">
                  Enhancer Configuration
                </span>
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="enhancer-device">Device</Label>
                <Select 
                  value={config.selected_config.enhancer_device}
                  onValueChange={(value) => handleConfigChange("lipsync", "enhancer_device", value)}
                >
                  <SelectTrigger id="enhancer-device">
                    <SelectValue placeholder="Select device" />
                  </SelectTrigger>
                  <SelectContent>
                    {config.devices.enhancer_device.map(option => (
                      <SelectItem key={`enhancer-${option.value}`} value={option.value}>
                        {option.value} | {option.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label htmlFor="enhancer-model">Model</Label>
                <Select 
                  value={config.selected_config.enhancer_model}
                  onValueChange={(value) => handleConfigChange("lipsync", "enhancer_model", value as EnhancerModel)}
                >
                  <SelectTrigger id="enhancer-model">
                    <SelectValue placeholder="Select model" />
                  </SelectTrigger>
                  <SelectContent>
                    {config.enhancer_models.map(option => (
                      <SelectItem key={option} value={option}>
                        {option}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </>
          )}
        </>
      ) : (
        <>
          <SelectSkeleton />
          <SelectSkeleton />
          <SwitchSkeleton />
        </>
      )}
    </ConfigSection>
  )
}
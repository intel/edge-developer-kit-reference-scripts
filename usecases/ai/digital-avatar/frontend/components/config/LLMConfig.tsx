"use client"

import { MessageSquare } from "lucide-react"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Input } from "@/components/ui/input"
import { Switch } from "@/components/ui/switch"
import { LLMConfigApiResponse, SelectedPipelineConfig } from "@/types/config"
import { ConfigSection } from "./ConfigSection"
import SliderControl from "./SliderControl"
import { Textarea } from "../ui/textarea"
import { LLMModelsSelect } from "../chat/settings/LLMModelsSelect"
import { SelectSkeleton, SliderSkeleton, TextareaSkeleton } from "./InputSkeletons"

export default function LLMConfig({ 
  config,
  handleConfigChange 
} : { 
  config?: LLMConfigApiResponse
  handleConfigChange: <K extends keyof SelectedPipelineConfig, T extends keyof SelectedPipelineConfig[K]>(
    section: K,
    key: T,
    value: SelectedPipelineConfig[K][T]
  ) => void 
}) {
  return (
    <ConfigSection
      title="LLM Configuration"
      icon={<MessageSquare className="h-5 w-5" />}
    >
      {config ? (
        <>
          <div className="space-y-2">
            <Label htmlFor="llm-system-prompt">Model</Label>
            <LLMModelsSelect 
              value={config.selected_config.llm_model} 
              updateValue={(value) => handleConfigChange("llm", "llm_model", value)} 
            />
          </div>

          <SliderControl
            id="llm-temperature"
            label="Temperature"
            value={config.selected_config.temperature}
            min={0}
            max={1}
            step={0.1}
            valueLabels={["0.0", "0.5", "1.0"]}
            onChange={(value) => handleConfigChange("llm", "temperature", value)}
          />

          <div className="space-y-2">
            <Label htmlFor="llm-system-prompt">System Prompt</Label>
            <Textarea
              id="llm-system-prompt"
              placeholder="Enter system prompt here..."
              className="min-h-[100px]"
              value={config.selected_config.system_prompt}
              onChange={(e) => handleConfigChange("llm", "system_prompt", e.target.value)}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="llm-max-tokens">Max Tokens</Label>
            <Input 
              id="llm-max-tokens" 
              type="number" 
              value={config.selected_config.max_tokens} 
              min={1} 
              max={8192}
              onChange={(e) => handleConfigChange("llm", "max_tokens", parseInt(e.target.value))}
            />
          </div>

          <div className="flex items-center space-x-2">
            <Switch 
              id="use-rag" 
              checked={config.selected_config.use_rag} 
              onCheckedChange={(checked) => handleConfigChange("llm", "use_rag", checked)} 
            />
            <Label htmlFor="use-rag">Use RAG</Label>
          </div>

          {config.selected_config.use_rag && (
            <>
              <div className="relative text-center text-sm after:absolute after:inset-0 after:top-1/2 after:z-0 after:flex after:items-center after:border-t after:border-border">
                <span className="relative z-10 bg-background px-2 text-muted-foreground">
                  RAG Configuration
                </span>
              </div>

              <div className="space-y-2">
                <Label htmlFor="llm-embedding-device">Embedding Device</Label>
                <Select 
                  value={config.selected_config.embedding_device}
                  onValueChange={(value) => handleConfigChange("llm", "embedding_device", value)}
                >
                  <SelectTrigger id="llm-embedding-device">
                    <SelectValue placeholder="Select device" />
                  </SelectTrigger>
                  <SelectContent>
                    {config.devices.map(option => (
                      <SelectItem key={`llm-embedding-${option.value}`} value={option.value}>
                        {option.value} | {option.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="llm-reranker-device">Reranker Device</Label>
                <Select 
                  value={config.selected_config.reranker_device}
                  onValueChange={(value) => handleConfigChange("llm", "reranker_device", value)}
                >
                  <SelectTrigger id="llm-reranker-device">
                    <SelectValue placeholder="Select device" />
                  </SelectTrigger>
                  <SelectContent>
                    {config.devices.map(option => (
                      <SelectItem key={`llm-reranker-${option.value}`} value={option.value}>
                        {option.value} | {option.name}
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
          <SliderSkeleton />
          <TextareaSkeleton />
          <SelectSkeleton />
        </>
      )}
    </ConfigSection>
  )
}
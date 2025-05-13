"use client"

import { useState, useCallback, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Configs, SelectedPipelineConfig } from "@/types/config"
import { toast } from "sonner"
import DenoiseConfig from "@/components/config/DenoiseConfig"
import STTConfig from "@/components/config/STTConfig"
import TTSConfig from "@/components/config/TTSConfig"
import LipsyncConfig from "@/components/config/LipsyncConfig"
import LLMConfig from "@/components/config/LLMConfig"
import { useGetConfig, useUpdateConfig } from "@/hooks/useConfig"

export default function ConfigurationPanel() {
  const { data: configResponse } = useGetConfig()
  const [selectedConfig, setSelectedConfig] = useState<Configs | null>(null)
  const [isSaving, setIsSaving] = useState(false)
  const [changedSections, setChangedSections] = useState<Set<keyof SelectedPipelineConfig>>(new Set());
  const updateConfig = useUpdateConfig()

  // Initialize selectedConfig when configResponse changes
  useEffect(() => {
    if (configResponse?.data) {
      setSelectedConfig(configResponse.data)
    }
  }, [configResponse])

  const handleConfigChange = useCallback(<K extends keyof SelectedPipelineConfig, T extends keyof SelectedPipelineConfig[K]>(
    section: K,
    key: T,
    value: SelectedPipelineConfig[K][T]
  ) => {
    setSelectedConfig(prev => {
      if (!prev) return null;
      setChangedSections((prevChanged) => new Set(prevChanged).add(section));
      return {
        ...prev,
        [section]: {
          ...prev[section],
          selected_config: {
            ...prev[section]?.selected_config,
            [key]: value
          }
        }
      };
    });
  }, []);

  const handleSave = async () => {
    try {
      if (selectedConfig) {
        setIsSaving(true);
        const updatedConfig = Array.from(changedSections).reduce((acc, section) => {
          acc[section] = selectedConfig[section].selected_config as any;
          return acc;
        }, {} as Partial<SelectedPipelineConfig>);

        updateConfig.mutate(updatedConfig, {
          onSuccess: (data) => {
            setSelectedConfig(data);
            setChangedSections(new Set());
            toast.success("Configuration saved successfully");
            setIsSaving(false);
          },
          onError: (error) => {
            console.error("Failed to save config:", error);
            toast.error("Failed to save configuration");
            setIsSaving(false);
          }
        });
      }
    } catch (error) {
      console.error("Error saving configuration:", error);
      toast.error("Error saving configuration");
      setIsSaving(false);
    }
  };

  if (configResponse && !configResponse.status) {
    return <div className="p-4 max-w-3xl mx-auto">Error loading configurations, please contact admin.</div>
  }

  return (
    <div className="space-y-6 max-w-3xl mx-auto p-4 md:p-6">
      <div className="flex justify-between gap-4 mt-6">
        <h1 className="text-2xl font-bold mb-6">Configuration Panel</h1>
        <div className="flex justify-end gap-4">
          <Button onClick={handleSave} disabled={isSaving || !selectedConfig}>
            {isSaving ? "Saving..." : "Save Configuration"}
          </Button>
        </div>
      </div>

      {/* Denoise Section */}
      <DenoiseConfig 
        config={selectedConfig ? selectedConfig.denoiseStt : undefined}
        handleConfigChange={handleConfigChange} 
      />

      {/* STT Section */}
      <STTConfig 
        config={selectedConfig ? selectedConfig.denoiseStt : undefined}
        handleConfigChange={handleConfigChange} 
      />

      {/* LLM Section */}
      <LLMConfig 
        config={selectedConfig ? selectedConfig.llm : undefined}
        handleConfigChange={handleConfigChange} 
      />

      {/* TTS Section */}
      <TTSConfig 
        config={selectedConfig ? selectedConfig.tts : undefined}
        handleConfigChange={handleConfigChange} 
      />

      {/* Lipsync Section */}
      <LipsyncConfig 
        config={selectedConfig ? selectedConfig.lipsync : undefined}
        handleConfigChange={handleConfigChange} 
      />
      
    </div>
  )
}
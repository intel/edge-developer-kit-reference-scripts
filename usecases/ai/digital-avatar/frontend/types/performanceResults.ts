import { SelectedPipelineConfig } from "./config"

interface PerformanceResultsBase {
  httpLatency?: number
  inferenceLatency?: number
}

export interface PerformanceResultsMetadata {
  inputAudioDurationInSeconds?: number
  promptTokens?: number
  completionTokens?: number
  totalTokens?: number
}

interface LLMPerformanceResults {
  totalLatency: number 
  ttft: number
  throughput: number
}

interface TTSPerformanceResults extends PerformanceResultsBase {
  metadata: {
    outputAudioDuration: number
  }
}

interface LipsyncPerformanceResults extends PerformanceResultsBase {
  metadata: {
    framesGenerated: number
  }
}

export interface PerformanceResults {
  denoise?: PerformanceResultsBase
  stt?: PerformanceResultsBase
  llm?: LLMPerformanceResults
  tts?: TTSPerformanceResults[]
  lipsync?: LipsyncPerformanceResults[]
  config?: SelectedPipelineConfig
  metadata?: PerformanceResultsMetadata
}
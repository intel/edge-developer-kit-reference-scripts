export interface SelectedPipelineConfig {
  denoiseStt: DenoiseSTTSelectedConfig
  llm: LLMSelectedConfig,
  tts: TTSSelectedConfig,
  lipsync: LipsyncSelectedConfig
}

export interface Configs {
  denoiseStt: DenoiseSTTConfigApiResponse
  llm: LLMConfigApiResponse,
  tts: TTSConfigApiResponse,
  lipsync: LipsyncConfigApiResponse
}

export interface ConfigSectionProps {
  title: string
  icon: React.ReactNode
  children: React.ReactNode
}

export interface SliderControlProps {
  id: string
  label: string
  value: number
  min: number
  max: number
  step: number
  valueLabels: string[]
  onChange: (value: number) => void
}

// Denoise/STT Config
export type Language = "english" | "malay" | "chinese";
export type STTModel = "openai/whisper-tiny" | "openai/whisper-base" | "openai/whisper-small" | "openai/whisper-medium" | "openai/whisper-large";
export type DenoiseModel = "noise-suppression-poconetlike-0001" | "noise-suppression-denseunet-ll-0001";
export type DenoiseModelPrecision = "FP16" | "FP32";

export interface Device {
  name: string;
  value: string;
}

export interface DenoiseSTTConfigOptions {
  language: Language[];
  devices: Device[];
  stt_models: STTModel[];
  denoise_models: DenoiseModel[];
  denoise_model_precisions: DenoiseModelPrecision[];
}

export interface DenoiseSTTSelectedConfig {
  language: Language;
  stt_device: string;
  stt_model: STTModel;
  denoise_device: string;
  denoise_model: DenoiseModel;
  denoise_model_precision: DenoiseModelPrecision;
}

export interface DenoiseSTTConfigApiResponse extends DenoiseSTTConfigOptions {
  selected_config: DenoiseSTTSelectedConfig;
}

export interface LLMConfigOptions {
  devices: Device[];
}

export interface LLMSelectedConfig {
  llm_model: string;
  system_prompt: string;
  temperature: number;
  max_tokens: number;
  use_rag: boolean;
  embedding_device: string;
  reranker_device: string;
}

export interface LLMConfigApiResponse extends LLMConfigOptions {
  selected_config: LLMSelectedConfig;
}

// TTS Config
export type Speaker = "female" | "male";

export interface TTSConfigOptions {
  speaker: Speaker[];
  devices: string[];
}

export interface TTSSelectedConfig {
  device: string;
  speed: number;
  speaker: Speaker;
}

export interface TTSConfigApiResponse extends TTSConfigOptions {
  selected_config: TTSSelectedConfig;
}

// Lipsync Config
export type LipsyncModel = "wav2lip" | "wav2lip_gan";
export type EnhancerModel = 
  "RealESRGAN_x2plus" | 
  "RealESRGAN_x4plus" | 
  "realesr-animevideov3" | 
  "realesr-general-x4v3" | 
  "realesr-general-x4v3-dn" | 
  "RealESRGAN_x4plus_anime_6B";

export interface LipsyncConfigOptions {
  lipsync_models: LipsyncModel[];
  enhancer_models: EnhancerModel[];
  devices: {
    lipsync_device: Device[];
    enhancer_device: Device[];
  };
}

export interface LipsyncSelectedConfig {
  lipsync_model: LipsyncModel;
  lipsync_device: string;
  use_enhancer: boolean;
  enhancer_device?: string;
  enhancer_model?: EnhancerModel;
}

export interface LipsyncConfigApiResponse extends LipsyncConfigOptions {
  selected_config: LipsyncSelectedConfig;
}
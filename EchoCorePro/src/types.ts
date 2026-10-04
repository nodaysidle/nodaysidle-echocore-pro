export type Provider = "elevenlabs" | "local" | "xai" | "openrouter";

export interface Voice {
  id: string;
  name: string;
  provider: "elevenlabs" | "local";
  category: "cloned" | "premade" | "local";
  language?: string;
  labels?: Record<string, string>;
  preview_url?: string;
  description?: string;
  sample_path?: string;
}

export interface TTSRequest {
  text: string;
  voice_id: string;
  provider: Provider;
  model_id?: string;
  speed?: number;
  stability?: number;
  similarity_boost?: number;
  style?: number;
}

export interface TTSResponse {
  id: string;
  filename: string;
  audio_url: string;
  text: string;
  voice_name: string;
  provider: string;
  duration: number;
  elapsed: number;
  timestamp: number;
}

export interface BackendHealth {
  status: string;
  platform: string;
  piper_models_count: number;
  elevenlabs_configured: boolean;
  xai_configured: boolean;
  openrouter_configured: boolean;
  audio_dir: string;
  data_dir: string;
  uptime: number;
}

export interface AppConfig {
  elevenlabs_api_key?: string;
  elevenlabs_api_key_masked?: string;
  xai_api_key?: string;
  xai_api_key_masked?: string;
  openrouter_api_key?: string;
  openrouter_api_key_masked?: string;
  default_provider: Provider;
  elevenlabs_model: string;
  xai_model: string;
  openrouter_model: string;
  speed: number;
  stability: number;
  similarity_boost: number;
  style: number;
}

export interface HistoryItem {
  id: string;
  filename: string;
  audio_url: string;
  text: string;
  voice_name: string;
  provider: string;
  duration: number;
  elapsed: number;
  timestamp: number;
}

export interface ToastMessage {
  id: string;
  type: "success" | "error" | "info";
  title: string;
  message?: string;
}

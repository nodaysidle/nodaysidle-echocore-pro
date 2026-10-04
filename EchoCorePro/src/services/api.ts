import { AppConfig, BackendHealth, HistoryItem, TTSRequest, TTSResponse, Voice } from "../types";

export const API_BASE = "http://127.0.0.1:8765";

export const api = {
  async getHealth(): Promise<BackendHealth> {
    const res = await fetch(`${API_BASE}/api/health`);
    if (!res.ok) throw new Error("Backend offline or unresponsive");
    return res.json();
  },

  async getConfig(): Promise<AppConfig> {
    const res = await fetch(`${API_BASE}/api/config`);
    if (!res.ok) throw new Error("Failed to load configuration");
    return res.json();
  },

  async updateConfig(update: Partial<AppConfig>): Promise<void> {
    const res = await fetch(`${API_BASE}/api/config`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(update),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({ detail: "Failed to save configuration" }));
      throw new Error(err.detail || "Failed to save configuration");
    }
  },

  async getVoices(): Promise<Voice[]> {
    const res = await fetch(`${API_BASE}/api/voices`);
    if (!res.ok) throw new Error("Failed to load voices");
    const data = await res.json();
    return data.voices || [];
  },

  async cloneVoice(formData: FormData): Promise<{ status: string; voice_id: string; name: string }> {
    const res = await fetch(`${API_BASE}/api/clone`, {
      method: "POST",
      body: formData,
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({ detail: "Failed to clone voice" }));
      throw new Error(err.detail || "Failed to clone voice");
    }
    return res.json();
  },

  async deleteVoice(voiceId: string): Promise<void> {
    const res = await fetch(`${API_BASE}/api/voices/${encodeURIComponent(voiceId)}`, {
      method: "DELETE",
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({ detail: "Failed to delete voice" }));
      throw new Error(err.detail || "Failed to delete voice");
    }
  },

  async generateTTS(req: TTSRequest): Promise<TTSResponse> {
    const res = await fetch(`${API_BASE}/api/tts`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(req),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({ detail: "Speech synthesis failed" }));
      throw new Error(err.detail || "Speech synthesis failed");
    }
    return res.json();
  },

  async enhanceScript(params: {
    text: string;
    provider: "xai" | "openrouter";
    mode?: "polish" | "dramatic" | "podcast" | "expand";
    custom_instruction?: string;
  }): Promise<{ enhanced_text: string; provider: string; model: string }> {
    const res = await fetch(`${API_BASE}/api/ai/enhance`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(params),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({ detail: "AI script enhancement failed" }));
      throw new Error(err.detail || "AI script enhancement failed");
    }
    return res.json();
  },

  async getHistory(): Promise<HistoryItem[]> {
    const res = await fetch(`${API_BASE}/api/history`);
    if (!res.ok) return [];
    const data = await res.json();
    return data.history || [];
  },

  async deleteHistory(id: string): Promise<void> {
    const res = await fetch(`${API_BASE}/api/history/${encodeURIComponent(id)}`, {
      method: "DELETE",
    });
    if (!res.ok) throw new Error("Failed to delete history item");
  },

  getAudioUrl(pathOrFilename: string): string {
    if (pathOrFilename.startsWith("http")) return pathOrFilename;
    if (pathOrFilename.startsWith("/api/audio/")) return `${API_BASE}${pathOrFilename}`;
    return `${API_BASE}/api/audio/${pathOrFilename}`;
  },
};

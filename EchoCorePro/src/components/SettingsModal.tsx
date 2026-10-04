import React, { useState } from "react";
import { Check, Eye, EyeOff, Key, Server, Settings2, ShieldCheck, X } from "lucide-react";
import { api } from "../services/api";
import { AppConfig, BackendHealth } from "../types";

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  config: AppConfig;
  health: BackendHealth | null;
  onConfigSaved: () => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({
  isOpen,
  onClose,
  config,
  health,
  onConfigSaved,
}) => {
  const [elevenKey, setElevenKey] = useState(config.elevenlabs_api_key || "");
  const [xaiKey, setXaiKey] = useState(config.xai_api_key || "");
  const [openrouterKey, setOpenrouterKey] = useState(config.openrouter_api_key || "");

  const [elevenModel, setElevenModel] = useState(config.elevenlabs_model || "eleven_multilingual_v2");
  const [xaiModel, setXaiModel] = useState(config.xai_model || "grok-4.20-non-reasoning");
  const [openrouterModel, setOpenrouterModel] = useState(config.openrouter_model || "openai/gpt-4o-mini");

  const [showKeys, setShowKeys] = useState<{ [key: string]: boolean }>({});
  const [isSaving, setIsSaving] = useState(false);
  const [saveMessage, setSaveMessage] = useState<string | null>(null);

  if (!isOpen) return null;

  const toggleShowKey = (id: string) => {
    setShowKeys((prev) => ({ ...prev, [id]: !prev[id] }));
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaving(true);
    setSaveMessage(null);

    try {
      await api.updateConfig({
        elevenlabs_api_key: elevenKey.trim(),
        xai_api_key: xaiKey.trim(),
        openrouter_api_key: openrouterKey.trim(),
        elevenlabs_model: elevenModel,
        xai_model: xaiModel,
        openrouter_model: openrouterModel,
      });

      setSaveMessage("Settings saved successfully.");
      onConfigSaved();
      setTimeout(() => {
        onClose();
      }, 700);
    } catch (err: any) {
      alert(`Error saving configuration: ${err.message || "Unknown error"}`);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-in fade-in duration-200">
      <div className="relative w-full max-w-xl rounded-2xl bg-[#0d1017] border border-white/[0.1] shadow-2xl p-6 sm:p-7 overflow-hidden">
        {/* Top Glow Accent */}
        <div className="absolute top-0 left-1/4 right-1/4 h-px bg-gradient-to-r from-transparent via-cyan-400 to-transparent" />

        {/* Modal Header */}
        <div className="flex items-center justify-between pb-4 border-b border-white/[0.08]">
          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-xl bg-cyan-500/10 border border-cyan-500/20 text-cyan-400">
              <Settings2 className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-white tracking-tight">Engine & API Credentials</h2>
              <p className="text-xs text-slate-400">Keys are stored strictly on your local machine in ~/.config/echocore</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-white/[0.06] transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Modal Form */}
        <form onSubmit={handleSave} className="mt-5 space-y-4 max-h-[75vh] overflow-y-auto pr-1 custom-scrollbar">
          {/* ElevenLabs API Key */}
          <div className="space-y-1.5 p-3.5 rounded-xl bg-white/[0.02] border border-white/[0.06]">
            <div className="flex items-center justify-between">
              <label className="text-xs font-semibold text-slate-200 flex items-center gap-1.5">
                <Key className="w-3.5 h-3.5 text-cyan-400" />
                ElevenLabs API Key (Voice Cloning & TTS)
              </label>
              <a
                href="https://elevenlabs.io/app/settings/api-keys"
                target="_blank"
                rel="noreferrer"
                className="text-[11px] text-cyan-400 hover:underline"
              >
                Get API Key
              </a>
            </div>
            <div className="relative">
              <input
                type={showKeys["eleven"] ? "text" : "password"}
                placeholder="sk_..."
                value={elevenKey}
                onChange={(e) => setElevenKey(e.target.value)}
                className="w-full px-3 py-2 pr-10 text-xs rounded-lg bg-black/40 border border-white/[0.1] focus:border-cyan-400 focus:outline-none text-white font-mono placeholder-slate-600"
              />
              <button
                type="button"
                onClick={() => toggleShowKey("eleven")}
                className="absolute right-2.5 top-2.5 text-slate-400 hover:text-white cursor-pointer"
              >
                {showKeys["eleven"] ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
              </button>
            </div>

            <div className="pt-2 flex items-center justify-between">
              <span className="text-[11px] text-slate-400">Synthesis Model:</span>
              <select
                value={elevenModel}
                onChange={(e) => setElevenModel(e.target.value)}
                className="px-2 py-1 text-xs rounded bg-black/50 border border-white/[0.1] text-slate-200 focus:outline-none font-mono"
              >
                <option value="eleven_multilingual_v2">eleven_multilingual_v2 (Highest Quality)</option>
                <option value="eleven_turbo_v2_5">eleven_turbo_v2_5 (Low Latency)</option>
                <option value="eleven_flash_v2_5">eleven_flash_v2_5 (Ultra Fast)</option>
              </select>
            </div>
          </div>

          {/* x.ai (Grok) API Key */}
          <div className="space-y-1.5 p-3.5 rounded-xl bg-white/[0.02] border border-white/[0.06]">
            <div className="flex items-center justify-between">
              <label className="text-xs font-semibold text-slate-200 flex items-center gap-1.5">
                <Key className="w-3.5 h-3.5 text-purple-400" />
                x.ai (Grok) API Key (Script Polish & Enhancement)
              </label>
              <a
                href="https://console.x.ai/"
                target="_blank"
                rel="noreferrer"
                className="text-[11px] text-purple-400 hover:underline"
              >
                Get API Key
              </a>
            </div>
            <div className="relative">
              <input
                type={showKeys["xai"] ? "text" : "password"}
                placeholder="xai-..."
                value={xaiKey}
                onChange={(e) => setXaiKey(e.target.value)}
                className="w-full px-3 py-2 pr-10 text-xs rounded-lg bg-black/40 border border-white/[0.1] focus:border-purple-400 focus:outline-none text-white font-mono placeholder-slate-600"
              />
              <button
                type="button"
                onClick={() => toggleShowKey("xai")}
                className="absolute right-2.5 top-2.5 text-slate-400 hover:text-white cursor-pointer"
              >
                {showKeys["xai"] ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
              </button>
            </div>

            <div className="pt-2 flex items-center justify-between">
              <span className="text-[11px] text-slate-400">Grok Model:</span>
              <select
                value={xaiModel}
                onChange={(e) => setXaiModel(e.target.value)}
                className="px-2 py-1 text-xs rounded bg-black/50 border border-white/[0.1] text-slate-200 focus:outline-none font-mono"
              >
                <option value="grok-4.20-non-reasoning">grok-4.20-non-reasoning (Fast & Polish)</option>
                <option value="grok-4.3">grok-4.3 (Deep Reasoning)</option>
              </select>
            </div>
          </div>

          {/* OpenRouter API Key */}
          <div className="space-y-1.5 p-3.5 rounded-xl bg-white/[0.02] border border-white/[0.06]">
            <div className="flex items-center justify-between">
              <label className="text-xs font-semibold text-slate-200 flex items-center gap-1.5">
                <Key className="w-3.5 h-3.5 text-amber-400" />
                OpenRouter API Key (Multi-Model AI Fallback)
              </label>
              <a
                href="https://openrouter.ai/keys"
                target="_blank"
                rel="noreferrer"
                className="text-[11px] text-amber-400 hover:underline"
              >
                Get API Key
              </a>
            </div>
            <div className="relative">
              <input
                type={showKeys["openrouter"] ? "text" : "password"}
                placeholder="sk-or-v1-..."
                value={openrouterKey}
                onChange={(e) => setOpenrouterKey(e.target.value)}
                className="w-full px-3 py-2 pr-10 text-xs rounded-lg bg-black/40 border border-white/[0.1] focus:border-amber-400 focus:outline-none text-white font-mono placeholder-slate-600"
              />
              <button
                type="button"
                onClick={() => toggleShowKey("openrouter")}
                className="absolute right-2.5 top-2.5 text-slate-400 hover:text-white cursor-pointer"
              >
                {showKeys["openrouter"] ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
              </button>
            </div>

            <div className="pt-2 flex items-center justify-between">
              <span className="text-[11px] text-slate-400">OpenRouter Model:</span>
              <input
                type="text"
                value={openrouterModel}
                onChange={(e) => setOpenrouterModel(e.target.value)}
                placeholder="openai/gpt-4o-mini"
                className="px-2 py-1 text-xs rounded bg-black/50 border border-white/[0.1] text-slate-200 focus:outline-none font-mono max-w-[200px]"
              />
            </div>
          </div>

          {/* Local Linux Engine Diagnostics */}
          <div className="p-3.5 rounded-xl bg-white/[0.02] border border-white/[0.06] text-xs space-y-1.5">
            <div className="flex items-center gap-1.5 font-semibold text-slate-300">
              <Server className="w-3.5 h-3.5 text-emerald-400" />
              <span>Local Engine Diagnostics</span>
            </div>
            <div className="grid grid-cols-2 gap-2 text-[11px] text-slate-400 font-mono pt-1">
              <div>Platform: Linux (Intel Arc / CPU)</div>
              <div>Offline Piper Voices: {health?.piper_models_count ?? 0} loaded</div>
              <div>Engine Uptime: {health?.uptime ?? 0}s</div>
              <div>Storage: ~/.config/echocore</div>
            </div>
          </div>

          {saveMessage && (
            <div className="flex items-center gap-2 p-2.5 rounded-lg bg-emerald-500/10 border border-emerald-500/20 text-emerald-300 text-xs">
              <Check className="w-4 h-4" />
              <span>{saveMessage}</span>
            </div>
          )}

          {/* Action buttons */}
          <div className="flex items-center justify-end gap-2.5 pt-3 border-t border-white/[0.08]">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-xs font-medium text-slate-300 hover:text-white bg-white/[0.04] hover:bg-white/[0.08] rounded-lg transition-colors cursor-pointer"
            >
              Cancel
            </button>

            <button
              type="submit"
              disabled={isSaving}
              className="flex items-center gap-2 px-5 py-2 text-xs font-semibold rounded-lg bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 text-white shadow-[0_0_20px_rgba(6,182,212,0.4)] transition-all cursor-pointer"
            >
              <ShieldCheck className="w-4 h-4" />
              {isSaving ? "Saving..." : "Save Credentials"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

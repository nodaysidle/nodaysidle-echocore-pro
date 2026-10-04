import React from "react";
import { Cpu, Globe, Key, Sparkles, Wand2, Zap } from "lucide-react";
import { AppConfig, Provider, Voice } from "../types";

interface ProviderSettingsTrayProps {
  provider: Provider;
  onProviderChange: (p: Provider) => void;
  config: AppConfig;
  onConfigChange: (c: Partial<AppConfig>) => void;
  selectedVoice: Voice | null;
  onGenerate: () => void;
  isGenerating: boolean;
  disabled: boolean;
  elevenlabsConfigured: boolean;
}

export const ProviderSettingsTray: React.FC<ProviderSettingsTrayProps> = ({
  provider,
  onProviderChange,
  config,
  onConfigChange,
  selectedVoice,
  onGenerate,
  isGenerating,
  disabled,
  elevenlabsConfigured,
}) => {
  const isClonedVoice = selectedVoice?.category === "cloned";

  return (
    <div className="flex flex-col gap-4 p-5 bg-[#0a0d14]/95 border border-white/[0.08] rounded-2xl shadow-2xl">
      {/* Top row: Engine Selection & Voice Fine-tuning */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        {/* Provider Switcher */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-300 uppercase tracking-wider flex items-center gap-1.5">
              <Zap className="w-3.5 h-3.5 text-cyan-400" />
              TTS Engine Provider
            </span>
          </div>

          <div className="grid grid-cols-2 gap-2">
            {/* ElevenLabs button */}
            <button
              onClick={() => onProviderChange("elevenlabs")}
              className={`flex items-center gap-2.5 p-2.5 rounded-xl border text-left transition-all cursor-pointer ${
                provider === "elevenlabs"
                  ? "bg-cyan-500/15 border-cyan-500/40 text-cyan-300 shadow-[inset_0_1px_1px_rgba(255,255,255,0.1)] ring-1 ring-cyan-500/20"
                  : "bg-white/[0.02] border-white/[0.06] text-slate-400 hover:bg-white/[0.05]"
              }`}
            >
              <Sparkles className="w-4 h-4 text-cyan-400 shrink-0" />
              <div className="min-w-0">
                <div className="text-xs font-bold text-white truncate">ElevenLabs</div>
                <div className="text-[10px] text-slate-400 truncate">
                  {elevenlabsConfigured ? "Cloning & Multilingual" : "Key needed in settings"}
                </div>
              </div>
            </button>

            {/* Local Piper button */}
            <button
              onClick={() => onProviderChange("local")}
              className={`flex items-center gap-2.5 p-2.5 rounded-xl border text-left transition-all cursor-pointer ${
                provider === "local"
                  ? "bg-emerald-500/15 border-emerald-500/40 text-emerald-300 shadow-[inset_0_1px_1px_rgba(255,255,255,0.1)] ring-1 ring-emerald-500/20"
                  : "bg-white/[0.02] border-white/[0.06] text-slate-400 hover:bg-white/[0.05]"
              }`}
            >
              <Cpu className="w-4 h-4 text-emerald-400 shrink-0" />
              <div className="min-w-0">
                <div className="text-xs font-bold text-white truncate">Local Piper</div>
                <div className="text-[10px] text-slate-400 truncate">Offline ONNX Linux</div>
              </div>
            </button>
          </div>
        </div>

        {/* Sliders: Stability & Similarity */}
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-300 uppercase tracking-wider">
              Acoustic Stability ({config.stability})
            </span>
          </div>
          <input
            type="range"
            min="0.1"
            max="1.0"
            step="0.05"
            value={config.stability}
            onChange={(e) => onConfigChange({ stability: parseFloat(e.target.value) })}
            className="w-full h-1.5 bg-white/[0.08] rounded-lg appearance-none cursor-pointer accent-cyan-400"
          />

          <div className="flex items-center justify-between pt-1">
            <span className="text-xs font-bold text-slate-300 uppercase tracking-wider">
              Clarity & Similarity ({config.similarity_boost})
            </span>
          </div>
          <input
            type="range"
            min="0.1"
            max="1.0"
            step="0.05"
            value={config.similarity_boost}
            onChange={(e) => onConfigChange({ similarity_boost: parseFloat(e.target.value) })}
            className="w-full h-1.5 bg-white/[0.08] rounded-lg appearance-none cursor-pointer accent-cyan-400"
          />
        </div>

        {/* Sliders: Speech Rate & Style Exaggeration */}
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-300 uppercase tracking-wider">
              Speech Speed ({config.speed}x)
            </span>
          </div>
          <input
            type="range"
            min="0.5"
            max="1.75"
            step="0.05"
            value={config.speed}
            onChange={(e) => onConfigChange({ speed: parseFloat(e.target.value) })}
            className="w-full h-1.5 bg-white/[0.08] rounded-lg appearance-none cursor-pointer accent-cyan-400"
          />

          <div className="flex items-center justify-between pt-1">
            <span className="text-xs font-bold text-slate-300 uppercase tracking-wider">
              Style Exaggeration ({config.style})
            </span>
          </div>
          <input
            type="range"
            min="0.0"
            max="1.0"
            step="0.05"
            value={config.style}
            onChange={(e) => onConfigChange({ style: parseFloat(e.target.value) })}
            className="w-full h-1.5 bg-white/[0.08] rounded-lg appearance-none cursor-pointer accent-cyan-400"
          />
        </div>
      </div>

      {/* Bottom row: Active Voice indicator & Primary Render Button */}
      <div className="flex flex-wrap items-center justify-between gap-4 pt-3 border-t border-white/[0.06]">
        <div className="flex items-center gap-3">
          <div className="text-xs text-slate-400">
            Selected Voice:{" "}
            <span className="font-semibold text-white">
              {selectedVoice ? selectedVoice.name : "None selected"}
            </span>
            {isClonedVoice && (
              <span className="ml-2 text-[10px] font-mono px-1.5 py-0.5 rounded bg-cyan-400/20 text-cyan-300 border border-cyan-400/30">
                CLONED PROFILE
              </span>
            )}
          </div>
        </div>

        {/* Generate / Render Speech CTA */}
        <div className="flex items-center gap-2">
          <span className="hidden sm:inline text-[11px] text-slate-500 font-mono">
            Press <kbd className="px-1.5 py-0.5 rounded bg-white/[0.08] text-slate-300 border border-white/[0.1]">Ctrl</kbd> + <kbd className="px-1.5 py-0.5 rounded bg-white/[0.08] text-slate-300 border border-white/[0.1]">Enter</kbd>
          </span>

          <button
            onClick={onGenerate}
            disabled={disabled || isGenerating}
            className={`relative flex items-center gap-2.5 px-7 py-3 text-sm font-bold rounded-xl text-black transition-all cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed ${
              isGenerating
                ? "bg-cyan-500/80 cursor-wait"
                : "bg-gradient-to-r from-cyan-400 via-teal-300 to-blue-400 hover:from-cyan-300 hover:to-blue-300 shadow-[0_0_30px_rgba(6,182,212,0.45)] hover:scale-[1.02] active:scale-[0.98]"
            }`}
          >
            {isGenerating ? (
              <>
                <Wand2 className="w-4 h-4 animate-spin text-black" />
                <span>Rendering Audio...</span>
              </>
            ) : (
              <>
                <Sparkles className="w-4 h-4 fill-black" />
                <span>{isClonedVoice ? "Render Cloned Voice" : "Generate Speech"}</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
};

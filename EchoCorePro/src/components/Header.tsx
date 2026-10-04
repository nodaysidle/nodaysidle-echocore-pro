import React from "react";
import { Activity, Cpu, KeyRound, Radio, Settings2, Sparkles, Volume2 } from "lucide-react";
import { BackendHealth } from "../types";

interface HeaderProps {
  health: BackendHealth | null;
  onOpenSettings: () => void;
  onOpenCloner: () => void;
}

export const Header: React.FC<HeaderProps> = ({ health, onOpenSettings, onOpenCloner }) => {
  const isOnline = health?.status === "online";

  return (
    <header className="relative z-10 flex items-center justify-between px-6 py-4 border-b border-white/[0.08] bg-[#090b10]/80 backdrop-blur-xl">
      {/* Brand & Identity */}
      <div className="flex items-center gap-3.5">
        <div className="relative flex items-center justify-center w-10 h-10 rounded-xl bg-gradient-to-br from-cyan-500/20 via-blue-500/10 to-purple-500/20 border border-cyan-500/30 shadow-[inset_0_1px_1px_rgba(255,255,255,0.2)]">
          <Volume2 className="w-5 h-5 text-cyan-400 animate-pulse" />
          <div className="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 rounded-full bg-cyan-400 ring-2 ring-[#090b10]" />
        </div>

        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-base font-bold tracking-tight text-white flex items-center gap-1.5">
              EchoCore <span className="text-xs px-1.5 py-0.5 rounded font-mono font-medium bg-cyan-500/15 text-cyan-300 border border-cyan-500/30">PRO</span>
            </h1>
            <span className="text-[11px] font-medium text-slate-400 px-2 py-0.5 rounded-full bg-white/[0.04] border border-white/[0.06]">
              Linux Studio
            </span>
          </div>
          <p className="text-xs text-slate-400 font-normal">
            Neural Voice Cloning & Unified Multi-Provider Speech Engine
          </p>
        </div>
      </div>

      {/* Engine Status Indicators */}
      <div className="flex items-center gap-3">
        {/* Backend Connectivity Status */}
        <div className="hidden sm:flex items-center gap-2 px-3 py-1.5 rounded-lg bg-white/[0.03] border border-white/[0.06] text-xs">
          <span className={`w-2 h-2 rounded-full ${isOnline ? "bg-emerald-400 shadow-[0_0_8px_rgba(52,211,153,0.6)]" : "bg-rose-400"}`} />
          <span className="text-slate-300 font-medium">{isOnline ? "Engine Online" : "Connecting..."}</span>
          {health && (
            <span className="text-[11px] text-slate-500 border-l border-white/[0.08] pl-2 font-mono">
              {health.piper_models_count} local models
            </span>
          )}
        </div>

        {/* API Keys quick badges */}
        <div className="hidden md:flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-white/[0.02] border border-white/[0.05] text-[11px]">
          <span className={`px-1.5 py-0.5 rounded font-mono font-medium ${health?.elevenlabs_configured ? "text-cyan-300 bg-cyan-500/10 border border-cyan-500/20" : "text-slate-500 bg-white/[0.03]"}`}>
            11Labs {health?.elevenlabs_configured ? "✓" : "—"}
          </span>
          <span className={`px-1.5 py-0.5 rounded font-mono font-medium ${health?.xai_configured ? "text-purple-300 bg-purple-500/10 border border-purple-500/20" : "text-slate-500 bg-white/[0.03]"}`}>
            xAI {health?.xai_configured ? "✓" : "—"}
          </span>
          <span className={`px-1.5 py-0.5 rounded font-mono font-medium ${health?.openrouter_configured ? "text-amber-300 bg-amber-500/10 border border-amber-500/20" : "text-slate-500 bg-white/[0.03]"}`}>
            OpenRouter {health?.openrouter_configured ? "✓" : "—"}
          </span>
        </div>

        {/* Quick Clone Voice Button */}
        <button
          onClick={onOpenCloner}
          className="flex items-center gap-2 px-3.5 py-2 text-xs font-semibold rounded-lg bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 text-white shadow-[0_0_20px_rgba(6,182,212,0.35)] transition-all hover:scale-[1.02] active:scale-[0.98] cursor-pointer"
        >
          <Sparkles className="w-3.5 h-3.5 text-cyan-100" />
          <span>Clone Voice</span>
        </button>

        {/* Settings button */}
        <button
          onClick={onOpenSettings}
          className="p-2 rounded-lg bg-white/[0.05] hover:bg-white/[0.1] text-slate-300 hover:text-white border border-white/[0.08] transition-colors cursor-pointer"
          title="Engine & API Key Settings"
        >
          <Settings2 className="w-4 h-4" />
        </button>
      </div>
    </header>
  );
};

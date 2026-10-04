import React, { useState } from "react";
import { Bot, Copy, Eraser, FileText, Sparkles, Undo2, Wand2 } from "lucide-react";
import { api } from "../services/api";

interface ScriptEditorProps {
  text: string;
  onChange: (text: string) => void;
  xaiConfigured: boolean;
  openrouterConfigured: boolean;
}

const PRESETS = [
  {
    title: "Podcast Intro",
    content:
      "Hey everyone, welcome back to the studio. Today we're diving deep into neural audio, real-time voice synthesis on Linux, and how open technology is reshaping creative expression. Grab a drink and let's get into it.",
  },
  {
    title: "Cinematic Narration",
    content:
      "Beyond the horizon of silence lies an uncharted signal. A voice that does not simply speak words, but carries the weight of memory, presence, and emotion across the machine.",
  },
  {
    title: "Product Keynote",
    content:
      "EchoCore Pro bridges on-device intelligence with unmatched acoustic fidelity. Built for developers and sound designers who demand full control, total privacy, and instantaneous rendering.",
  },
  {
    title: "Calm Meditation",
    content:
      "Take a slow, deep breath in... and let it gently release. Notice the quiet around you. With every exhale, release any tension in your shoulders and simply arrive in this moment.",
  },
];

export const ScriptEditor: React.FC<ScriptEditorProps> = ({
  text,
  onChange,
  xaiConfigured,
  openrouterConfigured,
}) => {
  const [isEnhancing, setIsEnhancing] = useState(false);
  const [previousText, setPreviousText] = useState<string | null>(null);
  const [enhanceMode, setEnhanceMode] = useState<"polish" | "dramatic" | "podcast" | "expand">("polish");
  const [showAiMenu, setShowAiMenu] = useState(false);

  const characterCount = text.length;
  const wordCount = text.trim() ? text.trim().split(/\s+/).length : 0;
  // Approximate reading duration at ~140 words per min
  const estimatedSeconds = Math.round((wordCount / 140) * 60);

  const handleEnhance = async (mode: "polish" | "dramatic" | "podcast" | "expand") => {
    if (!text.trim()) return;
    setIsEnhancing(true);
    setShowAiMenu(false);
    setPreviousText(text);

    try {
      const provider = xaiConfigured ? "xai" : "openrouter";
      const res = await api.enhanceScript({
        text,
        provider,
        mode,
      });
      onChange(res.enhanced_text);
    } catch (err: any) {
      alert(`AI enhancement notice: ${err.message || "Could not reach AI provider"}`);
    } finally {
      setIsEnhancing(false);
    }
  };

  const handleUndo = () => {
    if (previousText !== null) {
      onChange(previousText);
      setPreviousText(null);
    }
  };

  const hasAiProvider = xaiConfigured || openrouterConfigured;

  return (
    <div className="flex flex-col h-full bg-[#0c0f16]/90 border border-white/[0.08] rounded-2xl p-4 shadow-xl">
      {/* Top Bar with Presets & Character Stats */}
      <div className="flex flex-wrap items-center justify-between gap-2 pb-3 border-b border-white/[0.06]">
        <div className="flex items-center gap-2">
          <FileText className="w-4 h-4 text-cyan-400" />
          <span className="text-xs font-bold text-white tracking-wide uppercase">Voiceover Script</span>
          <span className="text-[11px] text-slate-500 font-mono">
            {wordCount} words • ~{estimatedSeconds}s audio
          </span>
        </div>

        {/* Quick Script Presets */}
        <div className="flex items-center gap-1.5 overflow-x-auto">
          {PRESETS.map((preset) => (
            <button
              key={preset.title}
              onClick={() => {
                setPreviousText(text);
                onChange(preset.content);
              }}
              className="px-2 py-0.5 text-[10px] font-medium rounded-md bg-white/[0.03] hover:bg-white/[0.07] text-slate-400 hover:text-slate-200 border border-white/[0.05] transition-colors cursor-pointer whitespace-nowrap"
            >
              {preset.title}
            </button>
          ))}
        </div>
      </div>

      {/* Main Textarea */}
      <div className="relative flex-1 mt-3">
        <textarea
          value={text}
          onChange={(e) => onChange(e.target.value)}
          placeholder="Type or paste the speech text here. Select a cloned voice or preset voice below and press Render to hear it spoken in real-time..."
          className="w-full h-full min-h-[200px] p-4 text-sm sm:text-base leading-relaxed rounded-xl bg-black/40 border border-white/[0.06] focus:border-cyan-500/50 focus:outline-none text-slate-100 placeholder-slate-600 resize-none font-sans"
        />

        {/* Floating Quick Action Icons */}
        <div className="absolute bottom-3 right-3 flex items-center gap-1.5 p-1 rounded-lg bg-[#090b10]/80 backdrop-blur-md border border-white/[0.08]">
          {previousText !== null && (
            <button
              onClick={handleUndo}
              className="flex items-center gap-1 px-2 py-1 text-[11px] text-slate-300 hover:text-white rounded hover:bg-white/[0.08] transition-colors cursor-pointer"
              title="Undo last change"
            >
              <Undo2 className="w-3.5 h-3.5" />
              <span>Undo</span>
            </button>
          )}

          <button
            onClick={() => {
              navigator.clipboard.writeText(text);
            }}
            className="p-1.5 text-slate-400 hover:text-white rounded hover:bg-white/[0.08] transition-colors cursor-pointer"
            title="Copy script"
          >
            <Copy className="w-3.5 h-3.5" />
          </button>

          <button
            onClick={() => {
              setPreviousText(text);
              onChange("");
            }}
            className="p-1.5 text-slate-400 hover:text-rose-400 rounded hover:bg-white/[0.08] transition-colors cursor-pointer"
            title="Clear text"
          >
            <Eraser className="w-3.5 h-3.5" />
          </button>

          {/* AI Script Polish */}
          <div className="relative">
            <button
              onClick={() => setShowAiMenu(!showAiMenu)}
              disabled={isEnhancing || !hasAiProvider || !text.trim()}
              className="flex items-center gap-1 px-2.5 py-1 text-xs font-semibold rounded-md bg-gradient-to-r from-purple-500/20 to-cyan-500/20 hover:from-purple-500/30 hover:to-cyan-500/30 text-purple-200 border border-purple-500/30 disabled:opacity-40 transition-all cursor-pointer shadow-sm"
              title={hasAiProvider ? "Enhance script with x.ai Grok or OpenRouter" : "Configure x.ai or OpenRouter key in Settings"}
            >
              <Wand2 className={`w-3.5 h-3.5 ${isEnhancing ? "animate-spin text-cyan-300" : "text-purple-300"}`} />
              <span>{isEnhancing ? "Polishing..." : "AI Polish"}</span>
            </button>

            {/* AI Menu dropdown */}
            {showAiMenu && (
              <div className="absolute bottom-full right-0 mb-2 w-48 rounded-xl bg-[#121622] border border-white/[0.1] shadow-2xl p-1.5 z-20 space-y-1">
                <div className="px-2 py-1 text-[10px] font-mono font-medium text-slate-400 uppercase border-b border-white/[0.06]">
                  Grok / AI Polish Mode
                </div>
                <button
                  onClick={() => handleEnhance("polish")}
                  className="w-full text-left px-2.5 py-1.5 text-xs text-slate-200 hover:bg-white/[0.08] rounded-lg transition-colors cursor-pointer"
                >
                  ✨ Spoken Polish
                </button>
                <button
                  onClick={() => handleEnhance("podcast")}
                  className="w-full text-left px-2.5 py-1.5 text-xs text-slate-200 hover:bg-white/[0.08] rounded-lg transition-colors cursor-pointer"
                >
                  🎙️ Podcast Conversational
                </button>
                <button
                  onClick={() => handleEnhance("dramatic")}
                  className="w-full text-left px-2.5 py-1.5 text-xs text-slate-200 hover:bg-white/[0.08] rounded-lg transition-colors cursor-pointer"
                >
                  🎬 Cinematic Dramatic
                </button>
                <button
                  onClick={() => handleEnhance("expand")}
                  className="w-full text-left px-2.5 py-1.5 text-xs text-slate-200 hover:bg-white/[0.08] rounded-lg transition-colors cursor-pointer"
                >
                  📝 Expand Idea into Monologue
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

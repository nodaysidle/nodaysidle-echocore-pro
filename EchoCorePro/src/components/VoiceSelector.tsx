import React, { useState } from "react";
import { Check, Cpu, Play, Plus, Search, Sparkles, Trash2, Volume2 } from "lucide-react";
import { Voice } from "../types";

interface VoiceSelectorProps {
  voices: Voice[];
  selectedVoiceId: string;
  onSelectVoice: (voice: Voice) => void;
  onOpenCloner: () => void;
  onDeleteVoice?: (voiceId: string) => void;
}

export const VoiceSelector: React.FC<VoiceSelectorProps> = ({
  voices,
  selectedVoiceId,
  onSelectVoice,
  onOpenCloner,
  onDeleteVoice,
}) => {
  const [filter, setFilter] = useState<"all" | "cloned" | "elevenlabs" | "local">("all");
  const [search, setSearch] = useState("");
  const [previewingId, setPreviewingId] = useState<string | null>(null);

  const filteredVoices = voices.filter((v) => {
    const matchesSearch =
      v.name.toLowerCase().includes(search.toLowerCase()) ||
      (v.description && v.description.toLowerCase().includes(search.toLowerCase()));

    if (!matchesSearch) return false;

    if (filter === "cloned") return v.category === "cloned";
    if (filter === "elevenlabs") return v.provider === "elevenlabs" && v.category !== "cloned";
    if (filter === "local") return v.provider === "local";
    return true;
  });

  const playPreview = (voice: Voice, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!voice.preview_url) return;

    if (previewingId === voice.id) {
      setPreviewingId(null);
      return;
    }

    const audio = new Audio(voice.preview_url);
    setPreviewingId(voice.id);
    audio.play();
    audio.onended = () => setPreviewingId(null);
  };

  const clonedCount = voices.filter((v) => v.category === "cloned").length;

  return (
    <div className="flex flex-col h-full bg-[#0c0f16]/90 border border-white/[0.08] rounded-2xl p-4 shadow-xl">
      {/* Top Bar with Filter Pills & Clone CTA */}
      <div className="flex items-center justify-between gap-2 mb-3">
        <div className="flex items-center gap-1.5 p-1 rounded-xl bg-white/[0.03] border border-white/[0.06] text-xs">
          <button
            onClick={() => setFilter("all")}
            className={`px-2.5 py-1 rounded-lg font-medium transition-all cursor-pointer ${
              filter === "all" ? "bg-white/[0.1] text-white shadow-sm" : "text-slate-400 hover:text-slate-200"
            }`}
          >
            All ({voices.length})
          </button>
          <button
            onClick={() => setFilter("cloned")}
            className={`flex items-center gap-1 px-2.5 py-1 rounded-lg font-medium transition-all cursor-pointer ${
              filter === "cloned"
                ? "bg-cyan-500/20 text-cyan-300 border border-cyan-500/30 shadow-sm"
                : "text-slate-400 hover:text-slate-200"
            }`}
          >
            <Sparkles className="w-3 h-3 text-cyan-400" />
            Cloned ({clonedCount})
          </button>
          <button
            onClick={() => setFilter("local")}
            className={`px-2.5 py-1 rounded-lg font-medium transition-all cursor-pointer ${
              filter === "local" ? "bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 shadow-sm" : "text-slate-400 hover:text-slate-200"
            }`}
          >
            Offline Local
          </button>
        </div>

        <button
          onClick={onOpenCloner}
          className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold rounded-xl bg-cyan-500/15 hover:bg-cyan-500/25 text-cyan-300 border border-cyan-500/30 transition-all hover:scale-[1.02] cursor-pointer"
        >
          <Plus className="w-3.5 h-3.5" />
          <span>New Clone</span>
        </button>
      </div>

      {/* Search Input */}
      <div className="relative mb-3">
        <Search className="absolute left-3 top-2.5 w-3.5 h-3.5 text-slate-400" />
        <input
          type="text"
          placeholder="Search voice name, accent, style..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full pl-8 pr-3 py-1.5 text-xs rounded-xl bg-black/40 border border-white/[0.08] focus:border-cyan-400 focus:outline-none text-slate-200 placeholder-slate-500"
        />
      </div>

      {/* Voice Cards List */}
      <div className="flex-1 overflow-y-auto space-y-2 pr-1 custom-scrollbar min-h-[180px]">
        {filteredVoices.length === 0 ? (
          <div className="flex flex-col items-center justify-center p-8 text-center text-slate-500 text-xs">
            <Volume2 className="w-6 h-6 mb-2 stroke-1 opacity-50" />
            <p>No voices matching filter</p>
            {filter === "cloned" && (
              <button
                onClick={onOpenCloner}
                className="mt-2 text-cyan-400 hover:underline cursor-pointer"
              >
                + Clone your first voice now
              </button>
            )}
          </div>
        ) : (
          filteredVoices.map((voice) => {
            const isSelected = voice.id === selectedVoiceId;
            const isCloned = voice.category === "cloned";
            const isLocal = voice.provider === "local";

            return (
              <div
                key={voice.id}
                onClick={() => onSelectVoice(voice)}
                className={`group relative flex items-center justify-between p-3 rounded-xl border transition-all cursor-pointer ${
                  isSelected
                    ? "bg-cyan-500/[0.12] border-cyan-500/40 shadow-[0_0_15px_rgba(6,182,212,0.15)] ring-1 ring-cyan-500/20"
                    : "bg-white/[0.02] hover:bg-white/[0.05] border-white/[0.06] hover:border-white/[0.12]"
                }`}
              >
                <div className="flex items-center gap-3 min-w-0">
                  <div
                    className={`flex items-center justify-center w-8 h-8 rounded-lg shrink-0 ${
                      isCloned
                        ? "bg-cyan-500/20 text-cyan-400 border border-cyan-500/30"
                        : isLocal
                        ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30"
                        : "bg-purple-500/20 text-purple-400 border border-purple-500/30"
                    }`}
                  >
                    {isCloned ? (
                      <Sparkles className="w-4 h-4" />
                    ) : isLocal ? (
                      <Cpu className="w-4 h-4" />
                    ) : (
                      <Volume2 className="w-4 h-4" />
                    )}
                  </div>

                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-semibold text-white truncate">{voice.name}</span>
                      {isCloned && (
                        <span className="text-[10px] font-mono px-1.5 py-0.2 rounded bg-cyan-400/15 text-cyan-300 border border-cyan-400/30 uppercase">
                          Cloned
                        </span>
                      )}
                      {isLocal && (
                        <span className="text-[10px] font-mono px-1.5 py-0.2 rounded bg-emerald-400/15 text-emerald-300 border border-emerald-400/30 uppercase">
                          Offline
                        </span>
                      )}
                    </div>
                    <p className="text-[11px] text-slate-400 truncate max-w-[200px]">
                      {voice.description || (isCloned ? "Custom Cloned Voice" : voice.provider)}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-1.5 shrink-0">
                  {voice.preview_url && (
                    <button
                      onClick={(e) => playPreview(voice, e)}
                      className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-white/[0.08] transition-colors"
                      title="Play Preview"
                    >
                      <Play className={`w-3.5 h-3.5 ${previewingId === voice.id ? "text-cyan-400 animate-pulse" : ""}`} />
                    </button>
                  )}

                  {isCloned && onDeleteVoice && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        if (confirm(`Delete cloned voice "${voice.name}"?`)) {
                          onDeleteVoice(voice.id);
                        }
                      }}
                      className="opacity-0 group-hover:opacity-100 p-1.5 rounded-lg text-slate-500 hover:text-rose-400 hover:bg-rose-500/10 transition-all"
                      title="Delete Voice"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  )}

                  {isSelected && (
                    <div className="p-1 rounded-full bg-cyan-400 text-black">
                      <Check className="w-3 h-3 stroke-[3]" />
                    </div>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};

import React, { useState } from "react";
import { ChevronDown, ChevronUp, Clock, Download, Play, Trash2, Volume2 } from "lucide-react";
import { api } from "../services/api";
import { HistoryItem } from "../types";

interface HistoryDrawerProps {
  history: HistoryItem[];
  onSelectAudio: (item: HistoryItem) => void;
  onRefreshHistory: () => void;
}

export const HistoryDrawer: React.FC<HistoryDrawerProps> = ({
  history,
  onSelectAudio,
  onRefreshHistory,
}) => {
  const [isOpen, setIsOpen] = useState(false);

  const handleDelete = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      await api.deleteHistory(id);
      onRefreshHistory();
    } catch (err) {
      console.error(err);
    }
  };

  const formatTimeAgo = (timestamp: number) => {
    const diff = Math.floor(Date.now() / 1000 - timestamp);
    if (diff < 60) return "just now";
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return `${Math.floor(diff / 86400)}d ago`;
  };

  return (
    <div className="bg-[#0b0e15]/90 border border-white/[0.08] rounded-2xl overflow-hidden shadow-xl">
      {/* Header bar to toggle drawer */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="w-full flex items-center justify-between px-5 py-3 text-left hover:bg-white/[0.02] transition-colors cursor-pointer"
      >
        <div className="flex items-center gap-2">
          <Clock className="w-4 h-4 text-cyan-400" />
          <span className="text-xs font-bold text-white tracking-wide uppercase">
            Recent Audio Generations ({history.length})
          </span>
        </div>
        <div className="flex items-center gap-1 text-slate-400 text-xs">
          <span>{isOpen ? "Hide History" : "Show History"}</span>
          {isOpen ? <ChevronDown className="w-4 h-4" /> : <ChevronUp className="w-4 h-4" />}
        </div>
      </button>

      {/* Expanded list of generations */}
      {isOpen && (
        <div className="p-4 pt-0 border-t border-white/[0.06]">
          {history.length === 0 ? (
            <p className="text-xs text-slate-500 py-3 text-center">No audio generated yet in this session.</p>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3 max-h-56 overflow-y-auto pr-1 custom-scrollbar mt-3">
              {history.map((item) => (
                <div
                  key={item.id}
                  onClick={() => onSelectAudio(item)}
                  className="group relative flex flex-col justify-between p-3 rounded-xl bg-white/[0.02] hover:bg-white/[0.06] border border-white/[0.06] hover:border-cyan-500/30 transition-all cursor-pointer"
                >
                  <div className="flex items-start justify-between gap-2 mb-1.5">
                    <span className="text-xs font-semibold text-white truncate">{item.voice_name}</span>
                    <span className="text-[10px] font-mono text-slate-500 shrink-0">
                      {formatTimeAgo(item.timestamp)}
                    </span>
                  </div>

                  <p className="text-[11px] text-slate-400 line-clamp-2 mb-2 leading-relaxed font-sans">
                    "{item.text}"
                  </p>

                  <div className="flex items-center justify-between pt-1 border-t border-white/[0.04] text-[10px] text-slate-500">
                    <span className="font-mono">
                      {item.duration}s • {item.provider}
                    </span>

                    <div className="flex items-center gap-1.5">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          const a = document.createElement("a");
                          a.href = api.getAudioUrl(item.audio_url);
                          a.download = item.filename;
                          a.click();
                        }}
                        className="p-1 text-slate-400 hover:text-white rounded hover:bg-white/[0.08]"
                        title="Download audio"
                      >
                        <Download className="w-3 h-3" />
                      </button>

                      <button
                        onClick={(e) => handleDelete(item.id, e)}
                        className="p-1 text-slate-400 hover:text-rose-400 rounded hover:bg-rose-500/10"
                        title="Delete render"
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

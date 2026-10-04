import React, { useEffect, useRef, useState } from "react";
import { AudioWaveform, Download, FastForward, Play, Pause, Repeat, Rewind, Volume2, VolumeX } from "lucide-react";
import WaveSurfer from "wavesurfer.js";
import { TTSResponse } from "../types";

interface WaveSurferStudioProps {
  currentAudio: TTSResponse | null;
  audioUrl: string | null;
}

export const WaveSurferStudio: React.FC<WaveSurferStudioProps> = ({ currentAudio, audioUrl }) => {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const waveSurferRef = useRef<WaveSurfer | null>(null);

  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(1.0);
  const [isMuted, setIsMuted] = useState(false);
  const [playbackRate, setPlaybackRate] = useState(1.0);
  const [isLooping, setIsLooping] = useState(false);

  useEffect(() => {
    if (!containerRef.current) return;

    if (waveSurferRef.current) {
      waveSurferRef.current.destroy();
      waveSurferRef.current = null;
    }

    if (!audioUrl) return;

    const ws = WaveSurfer.create({
      container: containerRef.current,
      waveColor: "rgba(255, 255, 255, 0.2)",
      progressColor: "#06b6d4",
      cursorColor: "#22d3ee",
      cursorWidth: 2,
      barWidth: 3,
      barGap: 3,
      barRadius: 3,
      height: 64,
      normalize: true,
    });

    waveSurferRef.current = ws;

    ws.load(audioUrl);

    ws.on("ready", () => {
      setDuration(ws.getDuration());
      setCurrentTime(0);
      setIsPlaying(false);
      // Auto play once ready
      ws.play();
      setIsPlaying(true);
    });

    ws.on("timeupdate", (time) => {
      setCurrentTime(time);
    });

    ws.on("play", () => setIsPlaying(true));
    ws.on("pause", () => setIsPlaying(false));
    ws.on("finish", () => {
      if (isLooping) {
        ws.play();
      } else {
        setIsPlaying(false);
      }
    });

    return () => {
      ws.destroy();
    };
  }, [audioUrl]);

  useEffect(() => {
    if (waveSurferRef.current) {
      waveSurferRef.current.setPlaybackRate(playbackRate);
    }
  }, [playbackRate]);

  useEffect(() => {
    if (waveSurferRef.current) {
      waveSurferRef.current.setVolume(isMuted ? 0 : volume);
    }
  }, [volume, isMuted]);

  const togglePlay = () => {
    if (waveSurferRef.current) {
      waveSurferRef.current.playPause();
    }
  };

  const skipSeconds = (seconds: number) => {
    if (waveSurferRef.current) {
      const target = Math.max(0, Math.min(duration, currentTime + seconds));
      waveSurferRef.current.setTime(target);
    }
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    const tenths = Math.floor((seconds % 1) * 10);
    return `${mins.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}.${tenths}`;
  };

  const handleDownload = () => {
    if (!audioUrl) return;
    const a = document.createElement("a");
    a.href = audioUrl;
    a.download = currentAudio?.filename || `echocore_speech_${Date.now()}.wav`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  };

  return (
    <div className="flex flex-col bg-[#0c0f16]/90 border border-white/[0.08] rounded-2xl p-4 shadow-xl">
      {/* Top Details Bar */}
      <div className="flex items-center justify-between gap-3 pb-3 border-b border-white/[0.06]">
        <div className="flex items-center gap-2">
          <div className="p-1.5 rounded-lg bg-cyan-500/10 text-cyan-400">
            <AudioWaveform className="w-4 h-4" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-xs font-bold text-white tracking-wide uppercase">Audio Workbench</span>
              {currentAudio && (
                <span className="text-[10px] font-mono font-medium px-2 py-0.5 rounded-full bg-cyan-500/15 text-cyan-300 border border-cyan-500/30">
                  {currentAudio.voice_name}
                </span>
              )}
            </div>
            {currentAudio ? (
              <span className="text-[11px] text-slate-400">
                Rendered in {currentAudio.elapsed}s via {currentAudio.provider} • Duration: {currentAudio.duration}s
              </span>
            ) : (
              <span className="text-[11px] text-slate-500">
                Awaiting render. Write script and click "Render Cloned Voice" below.
              </span>
            )}
          </div>
        </div>

        {/* Download Button */}
        {audioUrl && (
          <button
            onClick={handleDownload}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold rounded-xl bg-white/[0.04] hover:bg-white/[0.08] text-slate-200 border border-white/[0.08] transition-all hover:scale-[1.02] cursor-pointer"
          >
            <Download className="w-3.5 h-3.5 text-cyan-400" />
            <span>Export Audio</span>
          </button>
        )}
      </div>

      {/* WaveSurfer Visualizer Canvas */}
      <div className="relative my-3 p-3 rounded-xl bg-black/40 border border-white/[0.05]">
        <div ref={containerRef} className="w-full min-h-[64px]" />
        {!audioUrl && (
          <div className="absolute inset-0 flex items-center justify-center text-xs text-slate-600 font-mono">
            Interactive waveform will visualize here upon synthesis
          </div>
        )}
      </div>

      {/* Playback Controls & Scrubber */}
      <div className="flex flex-wrap items-center justify-between gap-4 pt-1">
        {/* Play/Pause & Skips */}
        <div className="flex items-center gap-2">
          <button
            onClick={() => skipSeconds(-5)}
            disabled={!audioUrl}
            className="p-2 text-slate-400 hover:text-white rounded-lg hover:bg-white/[0.06] transition-colors disabled:opacity-40 cursor-pointer"
            title="Rewind 5s"
          >
            <Rewind className="w-4 h-4" />
          </button>

          <button
            onClick={togglePlay}
            disabled={!audioUrl}
            className="flex items-center justify-center w-10 h-10 rounded-full bg-gradient-to-br from-cyan-400 to-blue-600 hover:from-cyan-300 hover:to-blue-500 text-black font-bold shadow-[0_0_18px_rgba(6,182,212,0.45)] transition-all hover:scale-105 active:scale-95 disabled:opacity-40 cursor-pointer"
          >
            {isPlaying ? <Pause className="w-5 h-5 fill-black" /> : <Play className="w-5 h-5 fill-black ml-0.5" />}
          </button>

          <button
            onClick={() => skipSeconds(5)}
            disabled={!audioUrl}
            className="p-2 text-slate-400 hover:text-white rounded-lg hover:bg-white/[0.06] transition-colors disabled:opacity-40 cursor-pointer"
            title="Forward 5s"
          >
            <FastForward className="w-4 h-4" />
          </button>

          {/* Time Code */}
          <div className="font-mono text-xs text-slate-300 ml-2">
            <span>{formatTime(currentTime)}</span>
            <span className="text-slate-500 mx-1">/</span>
            <span className="text-slate-500">{formatTime(duration)}</span>
          </div>
        </div>

        {/* Speed, Loop, Volume Controls */}
        <div className="flex items-center gap-3">
          {/* Loop button */}
          <button
            onClick={() => setIsLooping(!isLooping)}
            className={`p-2 rounded-lg transition-colors cursor-pointer ${
              isLooping ? "bg-cyan-500/20 text-cyan-300" : "text-slate-400 hover:text-white hover:bg-white/[0.06]"
            }`}
            title={isLooping ? "Loop Enabled" : "Loop Disabled"}
          >
            <Repeat className="w-4 h-4" />
          </button>

          {/* Speed Selector */}
          <div className="flex items-center gap-1 p-1 rounded-lg bg-white/[0.03] border border-white/[0.06] text-xs font-mono">
            {[0.75, 1.0, 1.25, 1.5].map((rate) => (
              <button
                key={rate}
                onClick={() => setPlaybackRate(rate)}
                className={`px-1.5 py-0.5 rounded cursor-pointer transition-all ${
                  playbackRate === rate ? "bg-cyan-500/20 text-cyan-300 font-bold" : "text-slate-400 hover:text-slate-200"
                }`}
              >
                {rate}x
              </button>
            ))}
          </div>

          {/* Volume Control */}
          <div className="flex items-center gap-1.5">
            <button
              onClick={() => setIsMuted(!isMuted)}
              className="text-slate-400 hover:text-white p-1 cursor-pointer"
            >
              {isMuted ? <VolumeX className="w-4 h-4 text-rose-400" /> : <Volume2 className="w-4 h-4" />}
            </button>
            <input
              type="range"
              min="0"
              max="1"
              step="0.05"
              value={isMuted ? 0 : volume}
              onChange={(e) => {
                setVolume(parseFloat(e.target.value));
                if (isMuted) setIsMuted(false);
              }}
              className="w-16 h-1 bg-white/[0.1] rounded-lg appearance-none cursor-pointer accent-cyan-400"
            />
          </div>
        </div>
      </div>
    </div>
  );
};

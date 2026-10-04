import React, { useEffect, useRef, useState } from "react";
import confetti from "canvas-confetti";
import { AlertCircle, CheckCircle2, Mic, MicOff, Play, RotateCcw, Sparkles, Square, Upload, X } from "lucide-react";
import { api } from "../services/api";
import { Voice } from "../types";

interface VoiceClonerModalProps {
  isOpen: boolean;
  onClose: () => void;
  onVoiceCloned: (newVoice: Voice) => void;
  elevenlabsConfigured: boolean;
}

export const VoiceClonerModal: React.FC<VoiceClonerModalProps> = ({
  isOpen,
  onClose,
  onVoiceCloned,
  elevenlabsConfigured,
}) => {
  const [tab, setTab] = useState<"upload" | "record">("upload");
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [targetProvider, setTargetProvider] = useState<"elevenlabs" | "local">(
    elevenlabsConfigured ? "elevenlabs" : "local"
  );
  const [audioFile, setAudioFile] = useState<File | null>(null);

  // Recording State
  const [isRecording, setIsRecording] = useState(false);
  const [recordedBlob, setRecordedBlob] = useState<Blob | null>(null);
  const [recordingSeconds, setRecordingSeconds] = useState(0);
  const [previewAudioUrl, setPreviewAudioUrl] = useState<string | null>(null);

  // Process status
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);
  const timerRef = useRef<number | null>(null);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const animationFrameRef = useRef<number | null>(null);

  useEffect(() => {
    if (!isOpen) {
      stopRecording();
      resetForm();
    }
  }, [isOpen]);

  const resetForm = () => {
    setName("");
    setDescription("");
    setAudioFile(null);
    setRecordedBlob(null);
    setRecordingSeconds(0);
    setError(null);
    if (previewAudioUrl) {
      URL.revokeObjectURL(previewAudioUrl);
      setPreviewAudioUrl(null);
    }
  };

  const startRecording = async () => {
    setError(null);
    audioChunksRef.current = [];
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mediaRecorder = new MediaRecorder(stream);
      mediaRecorderRef.current = mediaRecorder;

      // Audio visualizer setup
      const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
      audioContextRef.current = audioCtx;
      const source = audioCtx.createMediaStreamSource(stream);
      const analyser = audioCtx.createAnalyser();
      analyser.fftSize = 64;
      source.connect(analyser);

      const bufferLength = analyser.frequencyBinCount;
      const dataArray = new Uint8Array(bufferLength);

      const drawWaveform = () => {
        if (!canvasRef.current) return;
        const canvas = canvasRef.current;
        const ctx = canvas.getContext("2d");
        if (!ctx) return;

        analyser.getByteFrequencyData(dataArray);

        ctx.clearRect(0, 0, canvas.width, canvas.height);
        const barWidth = (canvas.width / bufferLength) * 2;
        let x = 0;

        for (let i = 0; i < bufferLength; i++) {
          const barHeight = (dataArray[i] / 255) * canvas.height;
          ctx.fillStyle = `rgba(6, 182, 212, ${Math.max(0.2, dataArray[i] / 255)})`;
          ctx.fillRect(x, canvas.height - barHeight, barWidth - 2, barHeight);
          x += barWidth;
        }

        animationFrameRef.current = requestAnimationFrame(drawWaveform);
      };

      drawWaveform();

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          audioChunksRef.current.push(event.data);
        }
      };

      mediaRecorder.onstop = () => {
        const blob = new Blob(audioChunksRef.current, { type: "audio/wav" });
        setRecordedBlob(blob);
        const url = URL.createObjectURL(blob);
        setPreviewAudioUrl(url);

        // Cleanup stream tracks
        stream.getTracks().forEach((track) => track.stop());
        if (animationFrameRef.current) cancelAnimationFrame(animationFrameRef.current);
        if (audioContextRef.current) audioContextRef.current.close();
      };

      mediaRecorder.start(200);
      setIsRecording(true);
      setRecordingSeconds(0);

      timerRef.current = window.setInterval(() => {
        setRecordingSeconds((prev) => prev + 1);
      }, 1000);
    } catch (err: any) {
      setError(`Microphone access error: ${err.message || "Permission denied"}`);
    }
  };

  const stopRecording = () => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop();
      setIsRecording(false);
      if (timerRef.current) {
        clearInterval(timerRef.current);
        timerRef.current = null;
      }
    }
  };

  const handleFileDrop = (e: React.DragEvent) => {
    e.preventDefault();
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      const file = e.dataTransfer.files[0];
      if (file.type.startsWith("audio/") || file.name.endsWith(".wav") || file.name.endsWith(".mp3")) {
        setAudioFile(file);
        setPreviewAudioUrl(URL.createObjectURL(file));
        if (!name) {
          setName(file.name.replace(/\.[^/.]+$/, "").replace(/[-_]/g, " "));
        }
      } else {
        setError("Please upload a valid audio file (.wav, .mp3, .m4a)");
      }
    }
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const file = e.target.files[0];
      setAudioFile(file);
      setPreviewAudioUrl(URL.createObjectURL(file));
      if (!name) {
        setName(file.name.replace(/\.[^/.]+$/, "").replace(/[-_]/g, " "));
      }
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    const voiceName = name.trim();
    if (!voiceName) {
      setError("Please provide a name for the cloned voice.");
      return;
    }

    let payloadFile: File | null = audioFile;
    if (tab === "record" && recordedBlob) {
      payloadFile = new File([recordedBlob], `${voiceName.toLowerCase().replace(/\s+/g, "_")}.wav`, {
        type: "audio/wav",
      });
    }

    if (!payloadFile) {
      setError("Please upload or record an audio sample first.");
      return;
    }

    setIsSubmitting(true);

    try {
      const formData = new FormData();
      formData.append("name", voiceName);
      formData.append("description", description.trim() || `Cloned voice profile for ${voiceName}`);
      formData.append("provider", targetProvider);
      formData.append("file", payloadFile);

      const res = await api.cloneVoice(formData);

      confetti({
        particleCount: 75,
        spread: 60,
        origin: { y: 0.7 },
        colors: ["#06b6d4", "#3b82f6", "#a855f7"],
      });

      const newVoice: Voice = {
        id: res.voice_id,
        name: res.name,
        provider: targetProvider,
        category: "cloned",
        description: description,
      };

      onVoiceCloned(newVoice);
      onClose();
    } catch (err: any) {
      setError(err.message || "Failed to clone voice.");
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-md animate-in fade-in duration-200">
      <div className="relative w-full max-w-xl rounded-2xl bg-[#0d1017] border border-white/[0.1] shadow-2xl p-6 sm:p-7 overflow-hidden">
        {/* Ambient Top Glow */}
        <div className="absolute top-0 left-1/4 right-1/4 h-px bg-gradient-to-r from-transparent via-cyan-400 to-transparent" />

        {/* Modal Header */}
        <div className="flex items-center justify-between pb-4 border-b border-white/[0.08]">
          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-xl bg-cyan-500/10 border border-cyan-500/20 text-cyan-400">
              <Sparkles className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-white tracking-tight">Instant Voice Cloner</h2>
              <p className="text-xs text-slate-400">Upload or record sample audio to synthesize in that exact voice</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-white/[0.06] transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="mt-5 space-y-4">
          {/* Target Provider Choice */}
          <div>
            <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1.5">
              Cloning Engine Destination
            </label>
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => setTargetProvider("elevenlabs")}
                className={`flex items-center gap-2 p-3 rounded-xl border text-left transition-all cursor-pointer ${
                  targetProvider === "elevenlabs"
                    ? "bg-cyan-500/10 border-cyan-500/40 text-cyan-300 shadow-[inset_0_1px_1px_rgba(255,255,255,0.1)]"
                    : "bg-white/[0.02] border-white/[0.06] text-slate-400 hover:bg-white/[0.04]"
                }`}
              >
                <div className={`w-2.5 h-2.5 rounded-full ${targetProvider === "elevenlabs" ? "bg-cyan-400" : "bg-slate-600"}`} />
                <div>
                  <div className="text-xs font-semibold text-white">ElevenLabs Cloud</div>
                  <div className="text-[10px] text-slate-400">Neural zero-shot cloning</div>
                </div>
              </button>

              <button
                type="button"
                onClick={() => setTargetProvider("local")}
                className={`flex items-center gap-2 p-3 rounded-xl border text-left transition-all cursor-pointer ${
                  targetProvider === "local"
                    ? "bg-cyan-500/10 border-cyan-500/40 text-cyan-300 shadow-[inset_0_1px_1px_rgba(255,255,255,0.1)]"
                    : "bg-white/[0.02] border-white/[0.06] text-slate-400 hover:bg-white/[0.04]"
                }`}
              >
                <div className={`w-2.5 h-2.5 rounded-full ${targetProvider === "local" ? "bg-cyan-400" : "bg-slate-600"}`} />
                <div>
                  <div className="text-xs font-semibold text-white">Local Library</div>
                  <div className="text-[10px] text-slate-400">Stored on your device</div>
                </div>
              </button>
            </div>
          </div>

          {/* Input Method Tabs */}
          <div>
            <div className="flex border-b border-white/[0.08] mb-3">
              <button
                type="button"
                onClick={() => setTab("upload")}
                className={`flex items-center gap-2 pb-2.5 px-3 text-xs font-medium border-b-2 transition-all cursor-pointer ${
                  tab === "upload"
                    ? "border-cyan-400 text-cyan-300 font-semibold"
                    : "border-transparent text-slate-400 hover:text-slate-200"
                }`}
              >
                <Upload className="w-3.5 h-3.5" />
                Upload Audio File
              </button>
              <button
                type="button"
                onClick={() => setTab("record")}
                className={`flex items-center gap-2 pb-2.5 px-3 text-xs font-medium border-b-2 transition-all cursor-pointer ${
                  tab === "record"
                    ? "border-cyan-400 text-cyan-300 font-semibold"
                    : "border-transparent text-slate-400 hover:text-slate-200"
                }`}
              >
                <Mic className="w-3.5 h-3.5" />
                Record Directly (Microphone)
              </button>
            </div>

            {/* Upload Area */}
            {tab === "upload" && (
              <div
                onDragOver={(e) => e.preventDefault()}
                onDrop={handleFileDrop}
                className="relative flex flex-col items-center justify-center p-6 border-2 border-dashed border-white/[0.12] hover:border-cyan-500/40 rounded-xl bg-white/[0.02] hover:bg-white/[0.04] transition-all cursor-pointer text-center group"
                onClick={() => document.getElementById("file-upload-input")?.click()}
              >
                <input
                  id="file-upload-input"
                  type="file"
                  accept="audio/*,.wav,.mp3,.m4a"
                  className="hidden"
                  onChange={handleFileSelect}
                />
                <div className="p-3 rounded-full bg-cyan-500/10 text-cyan-400 mb-2 group-hover:scale-110 transition-transform">
                  <Upload className="w-5 h-5" />
                </div>
                <p className="text-xs font-medium text-slate-200">
                  {audioFile ? audioFile.name : "Drag & drop reference audio or click to browse"}
                </p>
                <p className="text-[11px] text-slate-400 mt-1">
                  {audioFile
                    ? `${(audioFile.size / (1024 * 1024)).toFixed(2)} MB • Ready`
                    : "WAV, MP3, M4A — 15 to 60 seconds recommended"}
                </p>
              </div>
            )}

            {/* Record Area */}
            {tab === "record" && (
              <div className="flex flex-col items-center justify-center p-6 border border-white/[0.1] rounded-xl bg-white/[0.02] text-center">
                <canvas
                  ref={canvasRef}
                  width={280}
                  height={50}
                  className="w-full h-12 mb-3 rounded-lg bg-black/40 border border-white/[0.06]"
                />

                <div className="flex items-center gap-3">
                  {!isRecording ? (
                    <button
                      type="button"
                      onClick={startRecording}
                      className="flex items-center gap-2 px-4 py-2 rounded-xl bg-rose-500/20 text-rose-300 border border-rose-500/30 hover:bg-rose-500/30 transition-all font-semibold text-xs cursor-pointer"
                    >
                      <Mic className="w-4 h-4 text-rose-400 animate-pulse" />
                      {recordedBlob ? "Record Again" : "Start Recording"}
                    </button>
                  ) : (
                    <button
                      type="button"
                      onClick={stopRecording}
                      className="flex items-center gap-2 px-4 py-2 rounded-xl bg-rose-600 text-white hover:bg-rose-500 transition-all font-semibold text-xs cursor-pointer shadow-[0_0_15px_rgba(244,63,94,0.4)]"
                    >
                      <Square className="w-4 h-4 fill-white" />
                      Stop Recording ({recordingSeconds}s)
                    </button>
                  )}
                </div>

                <p className="text-[11px] text-slate-400 mt-2">
                  {isRecording
                    ? "Recording in progress... speak clearly into your mic"
                    : recordedBlob
                    ? `Recorded ${recordingSeconds} seconds successfully.`
                    : "Speak for at least 10–20 seconds for the most natural voice clone"}
                </p>
              </div>
            )}

            {/* Audio Preview playback if available */}
            {previewAudioUrl && (
              <div className="mt-3 flex items-center justify-between p-2.5 rounded-lg bg-white/[0.03] border border-white/[0.06]">
                <div className="flex items-center gap-2 text-xs text-slate-300">
                  <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                  <span>Sample audio ready for cloning</span>
                </div>
                <audio controls src={previewAudioUrl} className="h-8 max-w-[220px]" />
              </div>
            )}
          </div>

          {/* Voice Metadata Inputs */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1">Voice Profile Name *</label>
              <input
                type="text"
                placeholder="e.g. My Personal Clone"
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
                className="w-full px-3 py-2 text-xs rounded-lg bg-black/40 border border-white/[0.1] focus:border-cyan-400 focus:outline-none text-white placeholder-slate-500"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1">Tone / Description</label>
              <input
                type="text"
                placeholder="e.g. Warm, calm, podcast narration"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                className="w-full px-3 py-2 text-xs rounded-lg bg-black/40 border border-white/[0.1] focus:border-cyan-400 focus:outline-none text-white placeholder-slate-500"
              />
            </div>
          </div>

          {/* Error Message */}
          {error && (
            <div className="flex items-center gap-2 p-2.5 rounded-lg bg-rose-500/10 border border-rose-500/20 text-rose-300 text-xs">
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{error}</span>
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
              disabled={isSubmitting || (!audioFile && !recordedBlob)}
              className="flex items-center gap-2 px-5 py-2 text-xs font-semibold rounded-lg bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 disabled:opacity-50 text-white shadow-[0_0_20px_rgba(6,182,212,0.4)] transition-all cursor-pointer"
            >
              <Sparkles className="w-4 h-4" />
              {isSubmitting ? "Cloning Voice..." : "Clone Voice Now"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

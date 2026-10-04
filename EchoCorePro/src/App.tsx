import React, { useEffect, useState } from "react";
import confetti from "canvas-confetti";
import { Header } from "./components/Header";
import { HistoryDrawer } from "./components/HistoryDrawer";
import { ProviderSettingsTray } from "./components/ProviderSettingsTray";
import { ScriptEditor } from "./components/ScriptEditor";
import { SettingsModal } from "./components/SettingsModal";
import { ToastContainer } from "./components/Toast";
import { VoiceClonerModal } from "./components/VoiceClonerModal";
import { VoiceSelector } from "./components/VoiceSelector";
import { WaveSurferStudio } from "./components/WaveSurferStudio";
import { api } from "./services/api";
import { AppConfig, BackendHealth, HistoryItem, Provider, ToastMessage, TTSResponse, Voice } from "./types";

export const App: React.FC = () => {
  const [health, setHealth] = useState<BackendHealth | null>(null);
  const [config, setConfig] = useState<AppConfig>({
    default_provider: "local",
    elevenlabs_model: "eleven_multilingual_v2",
    xai_model: "grok-4.20-non-reasoning",
    openrouter_model: "openai/gpt-4o-mini",
    speed: 1.0,
    stability: 0.5,
    similarity_boost: 0.75,
    style: 0.0,
  });

  const [voices, setVoices] = useState<Voice[]>([]);
  const [selectedVoice, setSelectedVoice] = useState<Voice | null>(null);
  const [activeProvider, setActiveProvider] = useState<Provider>("local");

  const [text, setText] = useState<string>(
    "EchoCore Pro is a local speech and voice cloning workstation. You can type any script right here, clone a voice from a reference audio file, and render studio-grade speech instantly."
  );

  const [currentAudio, setCurrentAudio] = useState<TTSResponse | null>(null);
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const [history, setHistory] = useState<HistoryItem[]>([]);

  const [isGenerating, setIsGenerating] = useState(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [isClonerOpen, setIsClonerOpen] = useState(false);
  const [toasts, setToasts] = useState<ToastMessage[]>([]);

  const addToast = (type: "success" | "error" | "info", title: string, message?: string) => {
    const id = Math.random().toString(36).substring(2, 9);
    setToasts((prev) => [...prev, { id, type, title, message }]);
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 4500);
  };

  const removeToast = (id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  };

  // Initial Data Fetch
  const loadData = async () => {
    try {
      const [healthData, configData, voicesData, historyData] = await Promise.all([
        api.getHealth(),
        api.getConfig(),
        api.getVoices(),
        api.getHistory(),
      ]);

      setHealth(healthData);
      setConfig(configData);
      setVoices(voicesData);
      setHistory(historyData);

      // Select default provider based on key presence
      if (healthData.elevenlabs_configured) {
        setActiveProvider("elevenlabs");
      } else {
        setActiveProvider("local");
      }

      // Auto-select first voice if none selected
      if (!selectedVoice && voicesData.length > 0) {
        // Prefer cloned voice if present, else first available
        const cloned = voicesData.find((v) => v.category === "cloned");
        setSelectedVoice(cloned || voicesData[0]);
      }
    } catch (err: any) {
      console.warn("Failed to load initial backend state:", err);
      addToast("error", "Backend Offline", "Check that python server is running on 127.0.0.1:8765");
    }
  };

  useEffect(() => {
    loadData();
    const interval = setInterval(async () => {
      try {
        const h = await api.getHealth();
        setHealth(h);
      } catch {
        // silently wait
      }
    }, 10000);
    return () => clearInterval(interval);
  }, []);

  // Keyboard shortcut for generation: Ctrl + Enter
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
        e.preventDefault();
        handleGenerate();
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [text, selectedVoice, activeProvider, config, isGenerating]);

  const handleGenerate = async () => {
    if (!text.trim()) {
      addToast("info", "Script Empty", "Please write or paste script text first.");
      return;
    }

    if (!selectedVoice) {
      addToast("error", "No Voice Selected", "Please choose a voice from the voice library.");
      return;
    }

    // Auto-adjust provider if using local voice
    const effectiveProvider = selectedVoice.provider === "local" ? "local" : activeProvider;

    setIsGenerating(true);
    try {
      const res = await api.generateTTS({
        text,
        voice_id: selectedVoice.id,
        provider: effectiveProvider,
        model_id: config.elevenlabs_model,
        speed: config.speed,
        stability: config.stability,
        similarity_boost: config.similarity_boost,
        style: config.style,
      });

      setCurrentAudio(res);
      setAudioUrl(api.getAudioUrl(res.audio_url));

      // Refresh history
      const hist = await api.getHistory();
      setHistory(hist);

      addToast("success", "Synthesis Complete", `Generated ${res.duration}s in ${res.elapsed}s`);
    } catch (err: any) {
      addToast("error", "Synthesis Failed", err.message || "Unknown synthesis error");
    } finally {
      setIsGenerating(false);
    }
  };

  const handleVoiceCloned = async (newVoice: Voice) => {
    addToast("success", "Voice Cloned Successfully", `Profile "${newVoice.name}" is now ready to synthesize`);
    const updatedVoices = await api.getVoices();
    setVoices(updatedVoices);
    setSelectedVoice(newVoice);
    if (newVoice.provider === "elevenlabs") {
      setActiveProvider("elevenlabs");
    }
  };

  const handleDeleteVoice = async (voiceId: string) => {
    try {
      await api.deleteVoice(voiceId);
      addToast("info", "Voice Removed", "The cloned voice profile has been deleted.");
      const updated = await api.getVoices();
      setVoices(updated);
      if (selectedVoice?.id === voiceId) {
        setSelectedVoice(updated[0] || null);
      }
    } catch (err: any) {
      addToast("error", "Error", err.message || "Failed to remove voice");
    }
  };

  const handleSelectHistoryItem = (item: HistoryItem) => {
    const ttsItem: TTSResponse = {
      id: item.id,
      filename: item.filename,
      audio_url: item.audio_url,
      text: item.text,
      voice_name: item.voice_name,
      provider: item.provider,
      duration: item.duration,
      elapsed: item.elapsed,
      timestamp: item.timestamp,
    };
    setCurrentAudio(ttsItem);
    setAudioUrl(api.getAudioUrl(item.audio_url));
    setText(item.text);
    addToast("info", "Loaded Render", `Loaded previous render of "${item.voice_name}"`);
  };

  return (
    <div className="relative min-h-screen flex flex-col bg-[#07080c] text-slate-100 font-sans">
      {/* Dynamic Ambient Background Glow */}
      <div className="ambient-glow" />

      {/* Main Top Header */}
      <Header
        health={health}
        onOpenSettings={() => setIsSettingsOpen(true)}
        onOpenCloner={() => setIsClonerOpen(true)}
      />

      {/* Studio Workspace Container */}
      <main className="relative z-10 flex-1 flex flex-col max-w-7xl w-full mx-auto px-4 sm:px-6 py-5 gap-5">
        {/* Upper Split: Left = Voice Library & Clones | Right = Script Editor & Audio Workbench */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-5 flex-1 min-h-0">
          {/* Left Column: Voice Selector & Cloned Voice Profiles (5 cols) */}
          <div className="lg:col-span-4 flex flex-col min-h-[420px]">
            <VoiceSelector
              voices={voices}
              selectedVoiceId={selectedVoice?.id || ""}
              onSelectVoice={(v) => {
                setSelectedVoice(v);
                if (v.provider === "local") setActiveProvider("local");
                else if (health?.elevenlabs_configured) setActiveProvider("elevenlabs");
              }}
              onOpenCloner={() => setIsClonerOpen(true)}
              onDeleteVoice={handleDeleteVoice}
            />
          </div>

          {/* Right Column: Script Editor + Audio Workbench (8 cols) */}
          <div className="lg:col-span-8 flex flex-col gap-4">
            {/* Script Text Editor */}
            <div className="flex-1 min-h-[240px]">
              <ScriptEditor
                text={text}
                onChange={setText}
                xaiConfigured={Boolean(health?.xai_configured)}
                openrouterConfigured={Boolean(health?.openrouter_configured)}
              />
            </div>

            {/* Audio Workbench & WaveSurfer Player */}
            <WaveSurferStudio currentAudio={currentAudio} audioUrl={audioUrl} />
          </div>
        </div>

        {/* Lower Section: TTS Provider Switcher, Audio Sliders & Primary Generate Button */}
        <ProviderSettingsTray
          provider={activeProvider}
          onProviderChange={setActiveProvider}
          config={config}
          onConfigChange={(newCfg) => setConfig((prev) => ({ ...prev, ...newCfg }))}
          selectedVoice={selectedVoice}
          onGenerate={handleGenerate}
          isGenerating={isGenerating}
          disabled={!text.trim() || !selectedVoice}
          elevenlabsConfigured={Boolean(health?.elevenlabs_configured)}
        />

        {/* History Drawer */}
        <HistoryDrawer
          history={history}
          onSelectAudio={handleSelectHistoryItem}
          onRefreshHistory={async () => {
            const h = await api.getHistory();
            setHistory(h);
          }}
        />
      </main>

      {/* Voice Cloner Modal */}
      <VoiceClonerModal
        isOpen={isClonerOpen}
        onClose={() => setIsClonerOpen(false)}
        onVoiceCloned={handleVoiceCloned}
        elevenlabsConfigured={Boolean(health?.elevenlabs_configured)}
      />

      {/* Settings & Credentials Modal */}
      <SettingsModal
        isOpen={isSettingsOpen}
        onClose={() => setIsSettingsOpen(false)}
        config={config}
        health={health}
        onConfigSaved={loadData}
      />

      {/* Toast Notifications */}
      <ToastContainer toasts={toasts} onDismiss={removeToast} />
    </div>
  );
};

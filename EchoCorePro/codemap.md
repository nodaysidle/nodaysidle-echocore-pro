# Codemap: EchoCore Pro

> Neural Voice Studio & Multi-Provider Speech Engine (Linux & Cross-Platform)

## System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        TAURI V2 / BROWSER UI                           │
│  React 19 + TypeScript + Tailwind CSS v4 + WaveSurfer.js + Lucide-React │
├───────────────────────────────────┬────────────────────────────────────┤
│           Left Column             │            Right Column            │
│  • VoiceSelector                  │  • ScriptEditor                    │
│    - Cloned Voices filter         │    - Preset prompts (Podcast, etc) │
│    - Offline Piper filter         │    - AI Script Polish (Grok/OpenR) │
│    - Voice preview playback       │  • WaveSurferStudio                │
│    - Delete cloned voice          │    - Interactive waveform scrubber │
│  • VoiceClonerModal               │    - Play/Pause/Skip/Speed/Volume  │
│    - File upload (drag & drop)    │    - WAV/MP3 Export                │
│    - Live mic recording + visualizer                                   │
├───────────────────────────────────┴────────────────────────────────────┤
│  • ProviderSettingsTray: ElevenLabs | Local Piper | x.ai | OpenRouter  │
│    - Acoustic Stability, Similarity Boost, Speech Speed, Style sliders │
│    - Primary Glowing "Render Cloned Voice" CTA (Ctrl+Enter)            │
│  • HistoryDrawer: Recent render caching with instant reload & delete   │
│  • SettingsModal: Local secure API credentials (~/.config/echocore)    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ HTTP REST / JSON / Audio stream
┌───────────────────────────────────▼────────────────────────────────────┐
│                    PYTHON FASTAPI ENGINE (127.0.0.1:8765)              │
│  server/main.py (FastAPI, Uvicorn, httpx, soundfile, onnxruntime, piper)│
├────────────────────────────────────────────────────────────────────────┤
│  • Local Synthesis: Piper ONNX Engine (en_US-lessac, sl_SI-artur)      │
│  • ElevenLabs API: /v1/voices/add (Instant Cloning), /v1/text-to-speech │
│  • x.ai (Grok): /v1/chat/completions (Script writing & spoken polish)  │
│  • OpenRouter API: Multi-model AI script generation & audio routing    │
│  • Persistence: ~/.config/echocore/ (config.json, history, clones)     │
└────────────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
EchoCorePro/
├── package.json              # Scripts & dependencies (React 19, Tailwind 4, Wavesurfer, Tauri)
├── vite.config.ts            # Vite 7 build & Tauri dev server config
├── tsconfig.json             # TypeScript configuration
├── index.html                # App shell with dark theme & Plus Jakarta Sans typography
├── src/
│   ├── main.tsx              # React bootstrap
│   ├── App.tsx               # Main studio workspace & hotkey orchestration
│   ├── index.css             # Tailwind v4, glassmorphism & ambient specular layers
│   ├── types.ts              # TypeScript data interfaces
│   ├── services/
│   │   └── api.ts            # Typed client for backend communication
│   └── components/
│       ├── Header.tsx                 # Branding, health pills, settings trigger
│       ├── VoiceClonerModal.tsx       # Drag-and-drop & live mic voice cloning
│       ├── VoiceSelector.tsx          # Categorized voice filtering & previews
│       ├── ScriptEditor.tsx           # Text script editor with AI Polish
│       ├── WaveSurferStudio.tsx       # WaveSurfer interactive audio visualizer
│       ├── ProviderSettingsTray.tsx   # Provider switcher, sliders & primary CTA
│       ├── HistoryDrawer.tsx          # Past generations tray
│       ├── SettingsModal.tsx          # API keys & model selection
│       └── Toast.tsx                  # System notification toasts
├── server/
│   └── main.py               # FastAPI engine running on 127.0.0.1:8765
├── src-tauri/
│   ├── Cargo.toml            # Rust Tauri v2 manifest
│   ├── tauri.conf.json       # Desktop window configuration
│   ├── build.rs              # Tauri codegen build script
│   └── src/
│       ├── lib.rs            # Desktop application runner
│       └── main.rs           # Binary entrypoint
├── scripts/
│   └── run.sh                # Unified launcher (starts backend + frontend/desktop)
└── Models/
    └── Piper/                # Offline neural ONNX voices (English & Slovenian)
```

## API Endpoints

- `GET /api/health` — Status, model counts, provider readiness, uptime
- `GET /api/config` & `POST /api/config` — Retrieve & persist API keys and preferences
- `GET /api/voices` — Unified catalog of Cloned, ElevenLabs, and Local Piper voices
- `POST /api/clone` — Upload or record reference audio to create a cloned voice profile
- `POST /api/tts` — High-fidelity speech synthesis
- `POST /api/ai/enhance` — Script polish and script expansion via Grok / OpenRouter
- `GET /api/history` & `DELETE /api/history/{id}` — Manage cached generations
- `GET /api/audio/{filename}` — Audio stream & download

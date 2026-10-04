# Product Requirements — EchoCore Pro

## Product vision
EchoCore Pro is a neural voice workstation and speech synthesis engine for Linux and modern desktop workflows. It combines instant on-device and cloud voice cloning with a unified studio workspace for script editing, AI prompt polish, and multi-provider audio synthesis.

## Problem statement
Creators, developers, and audio producers need an intuitive, fast, and local-first tool for speech generation and voice cloning. Existing solutions are either fragmented across web browser UIs with expensive subscriptions, clunky command-line scripts, or locked into specific operating systems. EchoCore Pro unifies instant voice cloning, multi-provider API access (ElevenLabs, x.ai, OpenRouter), and offline neural synthesis (Piper ONNX) into a single cohesive, high-performance desktop studio.

## Goals
- Ship a native desktop workstation using Tauri v2, React 19, and Tailwind CSS.
- Provide instant voice cloning via both file upload (drag & drop) and live microphone recording with visual audio analysis.
- Unify multi-provider TTS: ElevenLabs (cloned and stock voices), offline Piper ONNX (English and Slovenian), x.ai (Grok), and OpenRouter.
- Deliver an interactive waveform workbench (WaveSurfer.js) with precise scrubbing, playback controls, and instant audio export.
- Integrate AI script polishing directly in the workspace to adapt text for spoken delivery, podcast conversation, or dramatic narration.
- Maintain safe, on-device local credential storage in `~/.config/echocore/`.
- Provide seamless desktop launcher integration for Omarchy and modern Linux environments (`Super + Space`).

## Non-goals
- Video rendering or video timeline editing.
- Proprietary closed-source cloud lock-in.
- Requiring cloud network connectivity for basic synthesis (local Piper engine runs 100% offline).

## Current scope
- Real-time voice cloning modal (drag & drop audio, live microphone recording with spectrum visualization).
- Unified multi-provider TTS pipeline (ElevenLabs, Piper ONNX, x.ai, OpenRouter).
- Script editor with character/word counting and AI polish integration.
- WaveSurfer audio workbench with scrubber, speed, loop, and download.
- Generation history drawer with persistent local caching and replay.
- Secure API key and model management via Settings modal.
- Native Linux desktop integration via Tauri v2 and desktop launcher.

## Success criteria
- Production build passes (`npm run build` and `npm run tauri build`).
- Instant voice cloning creates and selects cloned voice profiles in real-time.
- Local Piper engine generates offline speech in under 1.5 seconds.
- Desktop launcher (`~/.local/share/applications/echocore-pro.desktop`) allows immediate launch from Omarchy menu (`Super + Space`).
- Complete documentation matches the shipped codebase.

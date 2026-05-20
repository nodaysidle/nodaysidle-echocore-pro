<p align="center">
  <strong>EchoCore Pro</strong>
</p>

<p align="center">
  <strong>Local voice intelligence engine for macOS — Metal-accelerated, offline-first, zero cloud.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014%2B-black?style=flat-square&logo=apple&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/Metal-accelerated-A2845E?style=flat-square" alt="Metal">
  <img src="https://img.shields.io/badge/AI-on--device-5856D6?style=flat-square" alt="On-device AI">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License">
</p>

---

EchoCore Pro brings professional voice AI directly to your machine. Real-time synthesis, model management, and audio post-processing — all running locally on Apple Silicon via Metal. Your voice data never leaves the device.

---

## Features

- **Metal-accelerated inference** — optimized shaders for sub-second, real-time voice synthesis on M-series chips
- **Offline-first** — download models once, run them forever with no cloud dependency
- **Model management** — one-click download and quantization of open-source voice models into Apple Silicon-optimized formats
- **Audio workbench** — de-essing, parametric EQ, and dynamic normalization built in
- **Native macOS UI** — SwiftUI with glassmorphism, fluid animations, and Sonoma-native design

---

## Requirements

- macOS 14.0 Sonoma or later
- Apple Silicon (M1/M2/M3 recommended)
- 16GB+ RAM recommended for large models
- Xcode 15+ (for development builds)

---

## Building from Source

```bash
git clone https://gitlab.com/NODAYSIDLE/echocorepro.git
cd nodaysidle-echocore-pro
```

**Setup Python environment (ML engine):**

```bash
./Scripts/setup_venv.sh
```

**Build the macOS app:**

```bash
open EchoCorePro/EchoCorePro.xcodeproj
# Build target: EchoCorePro (⌘B)
```

---

## Architecture

- **Frontend (SwiftUI)** — UI, audio visualization, Metal rendering
- **Core (SwiftData)** — local persistence for models, history, and settings
- **Engine (Python Bridge)** — ML model orchestration (OpenVoice and compatible models) via a managed local environment

---

<p align="center">
  Built by <a href="https://gitlab.com/NODAYSIDLE">NODAYSIDLE</a>
</p>

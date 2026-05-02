# EchoCore Pro

EchoCore Pro is a native macOS speech app built around a bundled Python backend and a compact SwiftUI front end.
It keeps everything local on the machine: TTS, STT, model loading, and playback all stay on-device.

## Model stack

- **Primary TTS:** `mlx-community/Voxtral-4B-TTS-2603-mlx-4bit`
- **Slovenian TTS fallback:** Piper `sl_SI-artur-medium`
- **Speech-to-Text:** `mlx-community/whisper-small-mlx-q4`
- **Voice cloning:** not part of this workflow
- **Runtime:** local-only on Apple Silicon
- **Backend:** bound to `127.0.0.1:8765`

## What it does

- Generates speech with Voxtral for the main multilingual path
- Uses Piper only for Slovenian fallback
- Transcribes audio with bundled Whisper
- Launches the backend automatically from the app
- Shows model / health state in the Status tab

## Project layout

- `Sources/EchoCorePro/` — SwiftUI app, backend manager, models, and views
- `Runtime/backend.py` — local Flask backend
- `Runtime/venv/` — bundled Python runtime and dependencies
- `Models/` — bundled TTS and STT model assets
- `Resources/AppIcon.icns` — app icon
- `BuildScripts/package_app.sh` — release packaging / install script
- `Tests/EchoCoreProTests/` — model and backend contract tests

## Build

```bash
swift build -c release
```

## Test

```bash
swift test
```

## Package and install

```bash
./BuildScripts/package_app.sh
```

The script creates and installs:

```text
/Applications/EchoCorePro.app
```

It copies the bundled Python runtime and model assets into the app bundle, applies an ad-hoc local signature, and installs to `/Applications`.

## Run

Open the installed app:

```bash
open /Applications/EchoCorePro.app
```

The app starts the backend automatically. The Status view shows backend health, bundled model paths, and recent activity.

## Backend API

The backend is local-only and uses these endpoints:

- `GET /health`
- `GET /voices`
- `POST /tts`
- `POST /stt`

Example health check:

```bash
curl http://127.0.0.1:8765/health
```

## Workflow notes

- Voxtral is lazy-loaded on the first English / Italian TTS request.
- Slovenian uses Piper because that is the dedicated local fallback path.
- Whisper runs locally for transcription.
- First synthesis may take longer while the model loads into memory.

## Troubleshooting

If the app says the backend is offline:

```bash
curl http://127.0.0.1:8765/health
```

If another process is using port `8765`:

```bash
lsof -i :8765
```

If packaging fails, verify the required folders exist:

```bash
ls Runtime/backend.py Runtime/venv Models Resources/AppIcon.icns
```

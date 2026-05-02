# EchoCore Pro

EchoCore Pro is a native macOS app for running local speech models through a compact SwiftUI interface.
It launches a bundled Python backend automatically and keeps TTS / STT local on the machine.

## What it does

- Text-to-Speech with `mlx-community/Voxtral-4B-TTS-2603-mlx-4bit`
- Slovenian TTS fallback with Piper `sl_SI-artur-medium`
- Speech-to-Text with bundled `mlx-community/whisper-small-mlx-q4`
- Local-only processing on Apple Silicon
- Backend bound to `127.0.0.1:8765`

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

## Notes

- Voxtral is lazy-loaded on the first English / Italian TTS request.
- Slovenian uses Piper because that is the dedicated local fallback path.
- First synthesis may take longer while the model loads into memory.
- STT uses the bundled Whisper model and runs locally.

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

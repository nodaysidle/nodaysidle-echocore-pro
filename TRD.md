# Technical Requirements Document

## System context
EchoCore Pro is a SwiftPM macOS executable target with a SwiftUI front end and a bundled Python Flask backend.
The app talks to the backend over localhost only.
The backend owns the actual speech work; the Swift side manages UI, lifecycle, and request orchestration.

## Runtime endpoints

### GET /health
Returns backend readiness and model state.
Typical response fields:
- `status`
- `ready`
- `voxtral_loaded`
- `stt_ready`
- `models_ready`
- `model_status`
- `voice_status`
- `models_root`
- `uptime_seconds`
- `server_pid`
- `parent_pid`

### GET /voices
Returns the available voices by language.
Response shape:
- `voices_by_language: [String: [String]]`

### POST /tts
Request body JSON:
- `text`
- `language`
- `voice`
- `speed`

Behavior:
- English and the other bundled languages route through Voxtral.
- Slovenian routes through the bundled Piper fallback.
- Success returns `audio/wav`.
- Backend validation errors return JSON with `error`.

### POST /stt
Multipart upload with field name `audio`.
Behavior:
- The Swift client uploads a temporary file.
- The backend transcribes locally with bundled Whisper.
- Success returns JSON with at least `text`, `language`, and `duration_seconds`.

## Swift module contracts

### `EchoCoreProApp.swift`
- Creates the app scene.
- Injects a shared `BackendManager`.
- Starts backend monitoring on launch.

### `BackendManager.swift`
- Starts the bundled backend if nothing reachable is already running.
- Treats degraded-but-reachable health as connected, not as a trigger to spawn a second backend.
- Maintains `health`, `statusMessage`, `isRunning`, and recent activity.
- Builds multipart upload bodies for STT.

### `Models.swift`
- Defines the health, voice catalog, TTS request, STT response, and activity models.

### Views
- `ContentView.swift` owns navigation.
- `TTSView.swift` drives synthesis.
- `STTView.swift` drives transcription.
- `StatusView.swift` shows runtime state and activity.

## Verification strategy
When behavior changes, run:
- `swift test`
- `swift build -c release`
- package/install smoke test
- live `/health`, `/tts`, `/stt` checks against the installed app

## Edge cases that must stay covered
- Reachable but not ready backend should not cause a duplicate launch.
- Offline probe failure must clear stale status text.
- Multipart upload filenames must be sanitized for quotes and line breaks.

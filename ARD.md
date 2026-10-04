# Architecture Requirements Document

## Overview
EchoCore Pro is a local macOS speech app built from a SwiftPM executable target, a SwiftUI interface, and a bundled Python Flask backend.
The architecture is intentionally simple:
- SwiftUI handles navigation, forms, and status display.
- The backend handles actual TTS and STT work.
- The Swift client starts the backend, probes health, and forwards requests.

## Frontend architecture
- SwiftUI views compose the app shell.
- `ObservableObject` state is shared through `@EnvironmentObject`.
- `NavigationSplitView` is used for the main app structure.
- The UI is optimized for clarity and speed, not for a fake enterprise architecture layer.

## Backend architecture
- The backend is a bundled Python Flask app at `Runtime/backend.py`.
- It binds to `127.0.0.1:8765`.
- It serves `/health`, `/voices`, `/tts`, and `/stt`.
- The backend is expected to stay local and self-contained.
- The Swift client should treat any successful health response as a reachable backend, even if readiness is degraded.

## Data and persistence
- There is no SwiftData-backed domain model in the current shipped app.
- Temporary audio files are used for recording and STT upload plumbing.
- The backend and bundled model assets are the real stateful parts of the system.

## Packaging
- The shipped artifact is a macOS `.app` bundle.
- Packaging copies the bundled runtime and models into the app bundle.
- Smoke testing happens against the installed app, not just the source tree.

## Key trade-offs
- Bundling Python makes the app heavier but self-contained.
- A localhost backend keeps the UI simple and the runtime local.
- Keeping the architecture small reduces the chance of doc/code drift.

## Design priorities
- Local-first.
- Fast feedback.
- Predictable backend lifecycle.
- Honest docs.
- Fewer moving parts.

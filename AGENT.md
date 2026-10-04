# Agent Prompts — EchoCore Pro

## Purpose
EchoCore Pro is a native macOS speech app built as a SwiftPM executable target with a SwiftUI front end and a bundled local Python Flask backend.
The shipped workflow is local-first and currently centers on:
- `GET /health`
- `GET /voices`
- `POST /tts`
- `POST /stt`

## Hard rules
- Keep the app local-only. No cloud dependency for core functionality.
- Keep the real architecture aligned with the codebase: SwiftPM + SwiftUI + bundled Python backend.
- Do not invent SwiftData, CoreML, Metal pipelines, remote services, or Xcode-project-only assumptions unless the code actually uses them.
- Keep docs honest when implementation changes.
- Prefer the smallest safe change that fixes the bug.
- After any meaningful edit, run the relevant test/build/smoke check.

## Current product shape
- SwiftUI views: TTS, STT, Status, and the shared shell/navigation.
- Backend manager: launches and monitors the bundled Python backend.
- Backend runtime: `Runtime/backend.py` with bundled models and health checks.
- Packaging: release build + app bundle install path.

## Read order for maintenance work
1. `TRD.md` — actual endpoints, request/response shapes, and module contracts
2. `TASKS.md` — current maintenance backlog and acceptance criteria
3. `ARD.md` — architecture decisions and trade-offs
4. `PRD.md` — product scope and non-goals
5. `codemap.md` — file-by-file map of the real code

## Default execution pattern
- Inspect the code first.
- Patch only the files needed for the fix.
- Verify with `swift test`, `swift build -c release`, and app smoke tests when the change touches behavior.
- Update the docs in the same pass if the implementation changed.

## Output style
- Be blunt and factual.
- Call out when docs were stale.
- Do not preserve fictional architecture in future edits.

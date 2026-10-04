# Tasks Plan — EchoCore Pro

## Current maintenance backlog
This file reflects the real shipped app and the current audit findings.

## 1) Align docs with reality
- Rewrite any stale architecture docs so they describe the actual SwiftPM + SwiftUI + bundled Python backend app.
- Remove claims about Xcode-only scaffolding, SwiftData/CoreML/Metal pipelines, and fake endpoints.

### Acceptance criteria
- The docs mention the real endpoints: `/health`, `/voices`, `/tts`, `/stt`.
- The docs no longer describe a different app than the code.
- The README and codemap agree with the shipped architecture.

## 2) Harden backend lifecycle handling
- Split “reachable” from “ready” in the Swift backend manager.
- Do not launch a second backend just because `/health` reports degraded readiness.
- Keep status text in sync when probing fails.

### Acceptance criteria
- A degraded-but-responsive backend is treated as connected.
- Offline probe failures clear stale status text.
- App state still reflects the real backend state after refresh.

## 3) Harden multipart uploads
- Sanitize filenames before writing the STT multipart body.
- Cover quote and newline edge cases with a regression test.

### Acceptance criteria
- Problematic filenames do not break the multipart body.
- Regression tests pass for the sanitized header output.

## 4) Clean up state that should not go stale
- Use `isRunning` consistently or remove it if it becomes redundant.
- Keep the sidebar/status display aligned with backend connectivity.

### Acceptance criteria
- No dead state remains without a purpose.
- The visible status is derived from live backend state.

## 5) Keep verification honest
- Run the same checks the audit used whenever the runtime changes.

### Required checks
- `swift test`
- `swift build -c release`
- `./BuildScripts/package_app.sh`
- Live `/health`, `/tts`, and `/stt` smoke test against the installed app

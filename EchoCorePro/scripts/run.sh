#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "=== Starting EchoCore Pro Linux Studio ==="

# Check / start backend server
if ! curl -s http://127.0.0.1:8765/api/health > /dev/null 2>&1; then
    echo "Starting Python backend engine on 127.0.0.1:8765..."
    "$DIR/.venv-linux/bin/python" "$DIR/server/main.py" &
    SERVER_PID=$!
    trap 'kill $SERVER_PID 2>/dev/null || true' EXIT
    sleep 1.5
fi

# Launch mode: default to desktop tauri, or web if specified
MODE="${1:-desktop}"

if [ "$MODE" = "web" ]; then
    echo "Launching EchoCore Pro Web Studio on http://localhost:1420..."
    npm run dev
else
    echo "Launching EchoCore Pro Desktop Native Window (Tauri)..."
    npx tauri dev || {
        echo "Tauri dev encountered an issue, falling back to Vite web studio..."
        npm run dev
    }
fi

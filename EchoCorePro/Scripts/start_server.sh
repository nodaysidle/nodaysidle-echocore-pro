#!/usr/bin/env bash
# Quick start script for EchoCore Pro TTS Server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=================================================="
echo "  EchoCore Pro TTS Server"
echo "  Qwen3-TTS (Voice Cloning) + Kokoro (Natural TTS)"
echo "=================================================="
echo ""

# Check if venv exists
if [ ! -d "venv" ] && [ ! -L "venv" ]; then
    echo "Virtual environment not found!"
    echo "Run ./setup_tts.sh first to install dependencies."
    exit 1
fi

echo "Server: http://127.0.0.1:8765"
echo "Health: http://127.0.0.1:8765/health"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Use Python directly from venv (works in any shell)
./venv/bin/python tts_server.py

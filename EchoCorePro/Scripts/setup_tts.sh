#!/bin/bash
#
# EchoCore Pro TTS Setup Script
# Installs Qwen3-TTS (voice cloning via MLX) + Kokoro (high-quality TTS)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=================================================="
echo "  EchoCore Pro TTS Setup"
echo "  Qwen3-TTS (Voice Cloning) + Kokoro (Natural TTS)"
echo "=================================================="
echo ""

# Check Python version
PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
echo "Python version: $PYTHON_VERSION"

# Delete old venv if it exists (clean install)
if [ -d "venv" ]; then
    echo ""
    echo "Removing old virtual environment..."
    rm -rf venv
fi

echo ""
echo "Creating virtual environment..."
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

echo ""
echo "Upgrading pip..."
pip install --upgrade pip

echo ""
echo "=================================================="
echo "  Installing Core Dependencies"
echo "=================================================="

pip install flask flask-cors numpy scipy librosa soundfile

echo ""
echo "=================================================="
echo "  Installing Qwen3-TTS via MLX (Voice Cloning)"
echo "=================================================="
echo "  Model will be downloaded on first run (~2GB)"
echo ""

pip install mlx-audio

echo ""
echo "=================================================="
echo "  Installing Kokoro TTS via sherpa-onnx"
echo "=================================================="
echo ""

pip install sherpa-onnx

echo ""
echo "=================================================="
echo "  Downloading Kokoro Model Files"
echo "=================================================="
echo ""

KOKORO_DIR="$SCRIPT_DIR/kokoro_models"
mkdir -p "$KOKORO_DIR"

# Download Kokoro ONNX model from k2-fsa/sherpa-onnx releases
# This tar.bz2 includes model.onnx, voices.bin, tokens.txt, and espeak-ng-data/
if [ ! -f "$KOKORO_DIR/model.onnx" ]; then
    echo "Downloading Kokoro English model from sherpa-onnx releases..."
    KOKORO_TAR="kokoro-en-v0_19.tar.bz2"
    curl -L -o "$SCRIPT_DIR/$KOKORO_TAR" \
        "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/$KOKORO_TAR"

    echo "Extracting model files..."
    tar xf "$SCRIPT_DIR/$KOKORO_TAR" -C "$SCRIPT_DIR"

    # Move extracted files into kokoro_models/
    EXTRACTED_DIR="$SCRIPT_DIR/kokoro-en-v0_19"
    if [ -d "$EXTRACTED_DIR" ]; then
        cp -R "$EXTRACTED_DIR"/* "$KOKORO_DIR/"
        rm -rf "$EXTRACTED_DIR"
    fi

    rm -f "$SCRIPT_DIR/$KOKORO_TAR"
    echo "Kokoro model files downloaded and extracted!"
else
    echo "Kokoro model already downloaded."
fi

# Clean up old Piper voices if they exist
if [ -d "$SCRIPT_DIR/piper_voices" ]; then
    echo ""
    echo "Cleaning up old Piper voice files..."
    rm -rf "$SCRIPT_DIR/piper_voices"
    echo "Old Piper voices removed."
fi

echo ""
echo "=================================================="
echo "  Setup Complete!"
echo "=================================================="
echo ""
echo "Models will be downloaded on first run."
echo ""
echo "To start the server manually:"
echo "  cd $SCRIPT_DIR"
echo "  source venv/bin/activate"
echo "  python tts_server.py"
echo ""
echo "Server will run on: http://127.0.0.1:8765"
echo ""
echo "Available endpoints:"
echo "  GET  /health              - Health check"
echo "  POST /clone               - Clone a voice"
echo "  POST /qwen3/synthesize    - Voice cloning synthesis"
echo "  POST /kokoro/synthesize   - High-quality TTS synthesis"
echo "  GET  /kokoro/voices       - List Kokoro voices"
echo "  GET  /speakers            - List cloned speakers"
echo ""

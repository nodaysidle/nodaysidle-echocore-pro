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

# Download Kokoro ONNX model from HuggingFace
if [ ! -f "$KOKORO_DIR/kokoro-v0_19.onnx" ]; then
    echo "Downloading Kokoro v0.19 ONNX model..."
    pip install huggingface_hub
    python3 -c "
from huggingface_hub import hf_hub_download
import shutil, os

kokoro_dir = '$KOKORO_DIR'

# Download model files from hexgrad/Kokoro-82M
for filename in ['kokoro-v0_19.onnx', 'voices.bin', 'tokens.txt']:
    print(f'  Downloading {filename}...')
    path = hf_hub_download(repo_id='hexgrad/Kokoro-82M', filename=filename)
    shutil.copy2(path, os.path.join(kokoro_dir, filename))
    print(f'  Saved to {kokoro_dir}/{filename}')

print('Kokoro model files downloaded!')
"
else
    echo "Kokoro model already downloaded."
fi

# Download espeak-ng data for Kokoro
if [ ! -d "$KOKORO_DIR/kokoro-espeak-ng-data" ]; then
    echo ""
    echo "Downloading espeak-ng data for Kokoro..."
    python3 -c "
from huggingface_hub import snapshot_download
import shutil, os

kokoro_dir = '$KOKORO_DIR'
# Try to get espeak-ng data from sherpa-onnx kokoro model
try:
    path = snapshot_download(
        repo_id='k2-fsa/sherpa-onnx-tts-kokoro-en-v0_19',
        allow_patterns=['espeak-ng-data/*'],
        local_dir=kokoro_dir + '/tmp_download'
    )
    src = os.path.join(kokoro_dir, 'tmp_download', 'espeak-ng-data')
    dst = os.path.join(kokoro_dir, 'kokoro-espeak-ng-data')
    if os.path.exists(src):
        shutil.copytree(src, dst, dirs_exist_ok=True)
        print('espeak-ng data installed!')
    shutil.rmtree(os.path.join(kokoro_dir, 'tmp_download'), ignore_errors=True)
except Exception as e:
    print(f'Warning: Could not download espeak-ng data: {e}')
    print('Kokoro will still work, but some phonemes may not render correctly.')
"
else
    echo "espeak-ng data already present."
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

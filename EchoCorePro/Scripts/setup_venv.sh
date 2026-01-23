#!/usr/bin/env bash
# Setup script for EchoCore Pro Voice Cloning Server
# Supports: OpenVoice, XTTS v2, Qwen3-TTS, and more

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "🎙️  EchoCore Pro - Voice Cloning Setup"
echo "=============================================="

# Check for pkg-config and ffmpeg (required for PyAV)
if ! command -v pkg-config &> /dev/null; then
    echo "⚠️  pkg-config not found. Installing via Homebrew..."
    brew install pkg-config || {
        echo "❌ Please install Homebrew and run: brew install pkg-config ffmpeg"
        exit 1
    }
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "⚠️  ffmpeg not found. Installing via Homebrew..."
    brew install ffmpeg || {
        echo "❌ Please run: brew install ffmpeg"
        exit 1
    }
fi

# Remove old venv if exists
if [ -d "venv" ]; then
    echo "🗑️  Removing old venv..."
    rm -rf venv
fi

# Create venv with Python 3.11
echo "📦 Creating Python 3.11 venv..."
python3.11 -m venv venv

# Activate venv
source venv/bin/activate

# Upgrade pip
echo "⬆️  Upgrading pip..."
pip install --upgrade pip setuptools wheel

# Install PyTorch FIRST (many TTS libraries depend on it)
echo "🔥 Installing PyTorch with MPS support (Apple Silicon)..."
pip install torch torchvision torchaudio

# Install core audio processing libraries
echo "🎵 Installing audio processing libraries..."
pip install numpy scipy librosa soundfile pydub

# Install web framework
echo "🌐 Installing Flask..."
pip install flask flask-cors

# Install OpenVoice core files only (avoid dependency conflicts)
echo "🎤 Installing OpenVoice core..."
# Clone OpenVoice and install without its strict dependency requirements
pip install git+https://github.com/myshell-ai/OpenVoice.git --no-deps || {
    echo "⚠️  OpenVoice install failed, trying alternative..."
    pip install openvoice || echo "⚠️  OpenVoice not available, continuing..."
}

# Install OpenVoice runtime deps that work with modern Python
pip install inflect unidecode pypinyin jieba langid eng-to-ipa cn2an

# Install Coqui TTS (XTTS v2 - 17 languages including Italian)
echo "🇮🇹 Installing Coqui TTS (XTTS v2 - 17 languages)..."
pip install TTS || {
    echo "⚠️  TTS install failed, trying with pre-built wheels..."
    pip install --only-binary=:all: TTS || echo "⚠️  XTTS not available"
}

# Install Qwen3-TTS (high quality 10-language voice cloning)
echo "🌟 Installing Qwen3-TTS (10 languages)..."
pip install qwen-tts || {
    echo "⚠️  qwen-tts not available, trying transformers approach..."
    pip install transformers accelerate || echo "⚠️  Qwen3-TTS not available"
}

# Install Bark for expressive TTS
echo "🐕 Installing Bark (expressive TTS)..."
pip install git+https://github.com/suno-ai/bark.git || {
    echo "⚠️  Bark not available"
}

# Install SpeechT5
echo "�️  Installing SpeechT5 dependencies..."
pip install transformers datasets || echo "⚠️  SpeechT5 deps failed"

# Install faster-whisper for transcription
echo "📝 Installing faster-whisper..."
pip install faster-whisper || echo "⚠️  faster-whisper not available"

# Install PyAV for audio/video processing
echo "� Installing PyAV..."
pip install --only-binary=:all: av || {
    # Set FFmpeg paths for compilation
    export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:$PKG_CONFIG_PATH"
    export LDFLAGS="-L/opt/homebrew/lib"
    export CPPFLAGS="-I/opt/homebrew/include"
    pip install av || echo "⚠️  PyAV not available"
}

echo ""
echo "=============================================="
echo "✅ Setup complete!"
echo "=============================================="
echo ""
echo "Available models will be auto-detected at startup."
echo ""
echo "To run the server:"
echo "  cd $SCRIPT_DIR"
echo "  source venv/bin/activate"
echo "  python openvoice_server.py"
echo ""

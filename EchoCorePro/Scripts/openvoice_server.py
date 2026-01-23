#!/usr/bin/env python3
"""
EchoCore Pro Voice Cloning Server
Simplified version - Qwen3-TTS only
"""

from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import os
import sys
import tempfile
import logging

app = Flask(__name__)
CORS(app)

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Global storage for speaker audio paths
speakers = {}  # speaker_id -> {'audio_path': str, 'duration': float}

# Model globals
qwen3_model = None
qwen3_voice_prompts = {}  # Cache for reusable voice clone prompts
model_loaded = False
device = "cpu"

# Path to scripts
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def get_device():
    """Get the best available device"""
    try:
        import torch
        if torch.backends.mps.is_available():
            return "mps"
        elif torch.cuda.is_available():
            return "cuda"
        else:
            return "cpu"
    except:
        return "cpu"


def load_qwen3_model():
    """Load Qwen3-TTS-12Hz-1.7B-Base model"""
    global qwen3_model, device, model_loaded

    try:
        import torch
        from qwen_tts import Qwen3TTSModel
        logger.info("✅ Qwen3-TTS API imported successfully")
    except ImportError as e:
        logger.error(f"❌ qwen-tts not installed: {e}")
        logger.error("   Install with: pip install -U qwen-tts")
        return False

    try:
        device = get_device()

        # Determine dtype and device
        if device == "mps":
            qwen3_device = "mps"
            qwen3_dtype = torch.float32
            logger.info("🍎 Using MPS (Apple Silicon)")
        elif device == "cuda":
            qwen3_device = "cuda:0"
            qwen3_dtype = torch.bfloat16
            logger.info("🎮 Using CUDA")
        else:
            qwen3_device = "cpu"
            qwen3_dtype = torch.float32
            logger.info("💻 Using CPU")

        logger.info("📦 Loading Qwen3-TTS-12Hz-1.7B-Base...")
        logger.info("   First run will download ~2GB model")

        qwen3_model = Qwen3TTSModel.from_pretrained(
            "Qwen/Qwen3-TTS-12Hz-1.7B-Base",
            device_map=qwen3_device,
            dtype=qwen3_dtype,
        )

        logger.info("✅ Qwen3-TTS loaded!")
        logger.info("   Languages: EN, IT, DE, FR, ES, PT, RU, ZH, JA, KO")
        model_loaded = True
        return True

    except Exception as e:
        logger.error(f"❌ Failed to load Qwen3-TTS: {e}")
        import traceback
        traceback.print_exc()
        return False


def synthesize_with_qwen3(text, speaker_data, language='en', speed=1.0):
    """Synthesize speech using Qwen3-TTS"""
    try:
        import soundfile as sf
        import numpy as np
        import librosa

        logger.info(f"🎙️ Synthesizing: '{text[:50]}...' (lang={language})")

        # Get reference audio path
        audio_path = speaker_data.get('audio_path')
        speaker_id = speaker_data.get('id', 'default_speaker')

        if not audio_path or not os.path.exists(audio_path):
            raise ValueError("No reference audio available")

        # Qwen3 language mapping
        qwen3_lang_map = {
            'en': 'English', 'zh': 'Chinese', 'ja': 'Japanese', 'ko': 'Korean',
            'de': 'German', 'fr': 'French', 'ru': 'Russian', 'pt': 'Portuguese',
            'es': 'Spanish', 'it': 'Italian'
        }
        qwen3_language = qwen3_lang_map.get(language, 'Auto')

        # Check if we have a cached voice clone prompt
        if speaker_id in qwen3_voice_prompts:
            voice_clone_prompt = qwen3_voice_prompts[speaker_id]
            logger.info(f"🔄 Using cached voice: {speaker_id}")
        else:
            # Create voice clone prompt (x-vector mode - no transcript needed)
            voice_clone_prompt = qwen3_model.create_voice_clone_prompt(
                ref_audio=audio_path,
                ref_text="",
                x_vector_only_mode=True
            )
            qwen3_voice_prompts[speaker_id] = voice_clone_prompt
            logger.info(f"💾 Cached voice: {speaker_id}")

        # Generate speech
        wavs, sr = qwen3_model.generate_voice_clone(
            text=text,
            language=qwen3_language,
            voice_clone_prompt=voice_clone_prompt
        )

        # Process audio
        audio_data = wavs[0] if isinstance(wavs, list) else wavs
        if hasattr(audio_data, 'cpu'):
            audio_data = audio_data.cpu().numpy()
        if len(audio_data.shape) > 1:
            audio_data = audio_data.flatten()

        # Resample to 22050 Hz for macOS compatibility
        target_sr = 22050
        if sr != target_sr:
            audio_data = librosa.resample(audio_data, orig_sr=sr, target_sr=target_sr)
            sr = target_sr

        # Normalize
        max_val = np.max(np.abs(audio_data))
        if max_val > 0:
            audio_data = audio_data / max_val * 0.9

        # Save to WAV
        temp_output = tempfile.mktemp(suffix='.wav')
        sf.write(temp_output, audio_data, sr, subtype='PCM_16')

        # Validate the WAV file is readable
        try:
            test_audio, test_sr = sf.read(temp_output)
            if len(test_audio) == 0:
                raise ValueError("Generated audio is empty")
            logger.info(f"✅ Audio validated: {len(test_audio)} samples @ {test_sr}Hz")
        except Exception as e:
            logger.error(f"❌ Audio validation failed: {e}")
            raise ValueError(f"Invalid audio generated: {e}")

        file_size = os.path.getsize(temp_output)
        logger.info(f"✅ Audio: {file_size/1024:.1f} KB")

        return temp_output

    except Exception as e:
        logger.error(f"❌ Synthesis failed: {e}")
        import traceback
        traceback.print_exc()
        raise


# ==================== ROUTES ====================

@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'healthy' if model_loaded else 'unhealthy',
        'model_loaded': model_loaded,
        'model': 'Qwen3-TTS-1.7B',
        'speakers_loaded': len(speakers),
        'device': device
    })


@app.route('/clone', methods=['POST'])
def clone_voice():
    """Store reference audio for voice cloning"""
    if 'audio' not in request.files or 'speaker_id' not in request.form:
        return jsonify({'success': False, 'message': 'Missing audio or speaker_id'}), 400

    if not model_loaded:
        return jsonify({'success': False, 'message': 'Model not loaded'}), 503

    audio_file = request.files['audio']
    speaker_id = request.form['speaker_id']

    if not speaker_id or len(speaker_id) > 100:
        return jsonify({'success': False, 'message': 'Invalid speaker_id'}), 400

    try:
        import librosa

        # Save to permanent location
        speakers_dir = os.path.join(SCRIPT_DIR, "speakers")
        os.makedirs(speakers_dir, exist_ok=True)
        audio_path = os.path.join(speakers_dir, f"{speaker_id}.wav")

        audio_file.save(audio_path)

        # Validate audio duration (3-60 seconds)
        audio, sr = librosa.load(audio_path, sr=22050)
        duration = len(audio) / sr

        if duration < 3.0:
            os.unlink(audio_path)
            raise ValueError(f"Audio too short: {duration:.1f}s (minimum 3s)")
        if duration > 60.0:
            os.unlink(audio_path)
            raise ValueError(f"Audio too long: {duration:.1f}s (maximum 60s)")

        # Store speaker data
        speakers[speaker_id] = {
            'id': speaker_id,
            'audio_path': audio_path,
            'duration': duration
        }

        # Clear cached prompt so it gets recreated
        if speaker_id in qwen3_voice_prompts:
            del qwen3_voice_prompts[speaker_id]

        logger.info(f"✅ Voice cloned: {speaker_id} ({duration:.1f}s)")

        return jsonify({
            'success': True,
            'speaker_id': speaker_id,
            'duration_seconds': duration,
            'message': f'Voice "{speaker_id}" cloned! ({duration:.1f}s)'
        })

    except ValueError as e:
        logger.error(f"❌ Clone validation failed: {e}")
        return jsonify({'success': False, 'message': str(e)}), 400
    except Exception as e:
        logger.error(f"❌ Clone failed: {e}")
        return jsonify({'success': False, 'message': str(e)}), 500


@app.route('/synthesize', methods=['POST'])
def synthesize():
    """Synthesize speech with cloned voice"""
    if not model_loaded:
        return jsonify({'detail': 'Model not loaded'}), 503

    data = request.get_json()

    if not data or 'text' not in data or 'speaker_id' not in data:
        return jsonify({'detail': 'Missing text or speaker_id'}), 400

    text = data['text'].strip()
    speaker_id = data['speaker_id']
    language = data.get('language', 'en')
    speed = float(data.get('speed', 1.0))

    if not text:
        return jsonify({'detail': 'Text cannot be empty'}), 400
    if speaker_id not in speakers:
        return jsonify({'detail': f'Speaker "{speaker_id}" not found'}), 404
    if speed < 0.5 or speed > 2.0:
        return jsonify({'detail': 'Speed must be between 0.5 and 2.0'}), 400

    try:
        logger.info(f"🎤 Request: '{text[:50]}...' (speaker={speaker_id})")

        output_file = synthesize_with_qwen3(text, speakers[speaker_id], language, speed)

        response = send_file(output_file, mimetype='audio/wav', as_attachment=False)

        @response.call_on_close
        def cleanup():
            try:
                os.unlink(output_file)
            except:
                pass

        return response

    except Exception as e:
        logger.error(f"❌ Synthesis failed: {e}")
        return jsonify({'detail': str(e)}), 500


@app.route('/speakers', methods=['GET'])
def list_speakers():
    """List all cloned speakers"""
    return jsonify({
        'speakers': list(speakers.keys()),
        'count': len(speakers)
    })


@app.route('/speakers/<speaker_id>', methods=['DELETE'])
def delete_speaker(speaker_id):
    """Delete a cloned speaker"""
    if speaker_id in speakers:
        audio_path = speakers[speaker_id].get('audio_path')
        if audio_path and os.path.exists(audio_path):
            os.unlink(audio_path)
        # Also clear cached prompt
        if speaker_id in qwen3_voice_prompts:
            del qwen3_voice_prompts[speaker_id]
        del speakers[speaker_id]
        return jsonify({'message': f'Deleted {speaker_id}'})
    return jsonify({'detail': 'Not found'}), 404


@app.route('/shutdown', methods=['POST'])
def shutdown():
    """Gracefully shutdown the server"""
    logger.info("🛑 Shutdown requested")
    func = request.environ.get('werkzeug.server.shutdown')
    if func:
        func()
    return jsonify({'message': 'Shutting down'})


if __name__ == '__main__':
    print("=" * 50)
    print("🎙️  EchoCore Pro - Qwen3-TTS Voice Server")
    print("=" * 50)

    if load_qwen3_model():
        print(f"  Device: {device}")
        print("=" * 50)
        print("✅ Server ready!")
        print("🚀 http://127.0.0.1:8765")
        print("=" * 50)
    else:
        print("=" * 50)
        print("❌ Failed to load model!")
        print("   Run: pip install -U qwen-tts")
        print("=" * 50)

    app.run(host='127.0.0.1', port=8765, debug=False, threaded=True)

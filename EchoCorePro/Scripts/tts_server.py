#!/usr/bin/env python3
"""
EchoCore Pro TTS Server
- Qwen3-TTS: Voice cloning via MLX (fast on Apple Silicon)
- Kokoro: High-quality TTS via sherpa-onnx (natural voices)
"""

from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import os
import tempfile
import logging
import threading

app = Flask(__name__)
CORS(app)

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# ==================== CONFIGURATION ====================

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SPEAKERS_DIR = os.path.join(SCRIPT_DIR, "speakers")
KOKORO_DIR = os.path.join(SCRIPT_DIR, "kokoro_models")

for d in [SPEAKERS_DIR, KOKORO_DIR]:
    os.makedirs(d, exist_ok=True)

# Global state
qwen3_model = None
kokoro_tts = None
kokoro_voices_list = []
models_loaded = {"qwen3": False, "kokoro": False}

# Speaker storage: speaker_id -> {'audio_path': str, 'duration': float}
speakers = {}

# Qwen3-TTS supported languages
QWEN3_LANGUAGES = ['en', 'zh', 'ja', 'ko', 'fr', 'de', 'es', 'it', 'pt', 'ru']

# Kokoro voice metadata: id -> display info
# Kokoro voices follow pattern: {region}{gender}_{name}
# a = American, b = British, i = Italian
# f = female, m = male
KOKORO_VOICES = {
    "af_sarah": {"name": "Sarah", "gender": "female", "lang": "en_US"},
    "af_bella": {"name": "Bella", "gender": "female", "lang": "en_US"},
    "af_nicole": {"name": "Nicole", "gender": "female", "lang": "en_US"},
    "af_sky": {"name": "Sky", "gender": "female", "lang": "en_US"},
    "am_adam": {"name": "Adam", "gender": "male", "lang": "en_US"},
    "am_michael": {"name": "Michael", "gender": "male", "lang": "en_US"},
    "bf_emma": {"name": "Emma", "gender": "female", "lang": "en_GB"},
    "bf_isabella": {"name": "Isabella", "gender": "female", "lang": "en_GB"},
    "bm_george": {"name": "George", "gender": "male", "lang": "en_GB"},
    "bm_lewis": {"name": "Lewis", "gender": "male", "lang": "en_GB"},
    "if_sara": {"name": "Sara", "gender": "female", "lang": "it_IT"},
    "im_nicola": {"name": "Nicola", "gender": "male", "lang": "it_IT"},
}

# Languages supported by Kokoro
KOKORO_LANGUAGES = {
    "en_US": "English (US)",
    "en_GB": "English (UK)",
    "it_IT": "Italian",
}

# ==================== MODEL LOADING ====================

def load_qwen3_model():
    """Load Qwen3-TTS via mlx-audio for voice cloning"""
    global qwen3_model, models_loaded

    try:
        from mlx_audio.tts.utils import load_model

        logger.info("Loading Qwen3-TTS 1.7B (6-bit) via MLX...")
        qwen3_model = load_model("mlx-community/Qwen3-TTS-12Hz-1.7B-Base-6bit")
        models_loaded["qwen3"] = True
        logger.info("Qwen3-TTS loaded successfully!")
        return True

    except ImportError as e:
        logger.error(f"mlx-audio not installed: {e}")
        logger.error("Install with: pip install mlx-audio")
        return False
    except Exception as e:
        logger.error(f"Failed to load Qwen3-TTS: {e}")
        import traceback
        traceback.print_exc()
        return False


def load_kokoro_model():
    """Load Kokoro TTS for high-quality synthesis using sherpa-onnx"""
    global kokoro_tts, kokoro_voices_list, models_loaded

    try:
        import sherpa_onnx

        logger.info("Loading Kokoro TTS via sherpa-onnx...")

        model_path = os.path.join(KOKORO_DIR, "model.onnx")
        voices_path = os.path.join(KOKORO_DIR, "voices.bin")
        tokens_path = os.path.join(KOKORO_DIR, "tokens.txt")
        data_dir = os.path.join(KOKORO_DIR, "espeak-ng-data")

        if not os.path.exists(model_path):
            logger.error(f"Kokoro model not found at: {model_path}")
            logger.error("Run ./setup_tts.sh to download Kokoro models")
            return False

        tts_config = sherpa_onnx.OfflineTtsConfig(
            model=sherpa_onnx.OfflineTtsModelConfig(
                kokoro=sherpa_onnx.OfflineTtsKokoroModelConfig(
                    model=model_path,
                    voices=voices_path,
                    tokens=tokens_path,
                    data_dir=data_dir if os.path.exists(data_dir) else '',
                ),
                num_threads=4,
            ),
        )
        kokoro_tts = sherpa_onnx.OfflineTts(tts_config)

        # Build available voices list from what the model supports
        kokoro_voices_list = list(KOKORO_VOICES.keys())
        models_loaded["kokoro"] = True

        logger.info(f"Kokoro TTS ready! {len(kokoro_voices_list)} voices")
        return True

    except ImportError as e:
        logger.warning(f"sherpa-onnx not installed: {e}")
        return False
    except Exception as e:
        logger.error(f"Failed to load Kokoro: {e}")
        import traceback
        traceback.print_exc()
        return False


def load_speakers_from_disk():
    """Load existing speaker files on startup"""
    if not os.path.exists(SPEAKERS_DIR):
        os.makedirs(SPEAKERS_DIR, exist_ok=True)
        return

    try:
        import librosa
    except ImportError:
        logger.warning("librosa not installed, skipping speaker loading")
        return

    for filename in os.listdir(SPEAKERS_DIR):
        if filename.endswith('.wav'):
            speaker_id = filename[:-4]
            audio_path = os.path.join(SPEAKERS_DIR, filename)
            try:
                audio, sr = librosa.load(audio_path, sr=22050)
                duration = len(audio) / sr
                speakers[speaker_id] = {
                    'id': speaker_id,
                    'audio_path': audio_path,
                    'duration': duration
                }
                logger.info(f"Loaded speaker: {speaker_id} ({duration:.1f}s)")
            except Exception as e:
                logger.warning(f"Could not load {filename}: {e}")

    logger.info(f"Total: {len(speakers)} speakers loaded")

# ==================== TEXT CHUNKING ====================

import re

def chunk_text(text, max_chars=300):
    """Split text into chunks at natural sentence boundaries.

    Splits on sentence-ending punctuation (.!?) then groups into chunks
    that stay under max_chars. This keeps each TTS call within the
    model's max_tokens budget and produces more natural audio.
    """
    text = text.strip()
    if not text:
        return []

    # If short enough, return as single chunk
    if len(text) <= max_chars:
        return [text]

    # Split at sentence boundaries (keep the punctuation with the sentence)
    sentences = re.split(r'(?<=[.!?])\s+', text)

    chunks = []
    current_chunk = ""

    for sentence in sentences:
        sentence = sentence.strip()
        if not sentence:
            continue

        # If a single sentence exceeds max_chars, split it further at commas/semicolons
        if len(sentence) > max_chars:
            sub_parts = re.split(r'(?<=[,;:])\s+', sentence)
            for part in sub_parts:
                part = part.strip()
                if not part:
                    continue
                if current_chunk and len(current_chunk) + len(part) + 1 > max_chars:
                    chunks.append(current_chunk.strip())
                    current_chunk = part
                else:
                    current_chunk = f"{current_chunk} {part}".strip() if current_chunk else part
            continue

        # Normal sentence grouping
        if current_chunk and len(current_chunk) + len(sentence) + 1 > max_chars:
            chunks.append(current_chunk.strip())
            current_chunk = sentence
        else:
            current_chunk = f"{current_chunk} {sentence}".strip() if current_chunk else sentence

    if current_chunk.strip():
        chunks.append(current_chunk.strip())

    return chunks


# ==================== SYNTHESIS FUNCTIONS ====================

def synthesize_with_qwen3(text, speaker_data, language='en', speed=1.0,
                          temperature=0.9, top_k=50, top_p=1.0,
                          repetition_penalty=1.05, max_tokens=4096,
                          ref_text=""):
    """Synthesize with Qwen3-TTS voice cloning via MLX.

    Automatically chunks long text at sentence boundaries, synthesizes
    each chunk separately, then concatenates the audio.
    """
    import numpy as np
    import soundfile as sf

    audio_path = speaker_data.get('audio_path')
    if not audio_path or not os.path.exists(audio_path):
        raise ValueError("No reference audio available")

    # Map language codes to full names for Qwen3-TTS
    lang_map = {
        'en': 'English', 'zh': 'Chinese', 'ja': 'Japanese', 'ko': 'Korean',
        'fr': 'French', 'de': 'German', 'es': 'Spanish', 'it': 'Italian',
        'pt': 'Portuguese', 'ru': 'Russian',
    }
    lang_name = lang_map.get(language, 'English')

    # Chunk the text for reliable generation
    chunks = chunk_text(text, max_chars=300)
    total_chunks = len(chunks)

    logger.info(f"Qwen3-TTS synthesizing {total_chunks} chunk(s): '{text[:80]}...' "
                f"(lang={lang_name}, temp={temperature}, top_k={top_k}, top_p={top_p}, "
                f"rep_penalty={repetition_penalty}, max_tokens={max_tokens})")

    all_audio = []
    sample_rate = 24000

    for i, chunk in enumerate(chunks):
        logger.info(f"  Chunk {i+1}/{total_chunks}: '{chunk[:60]}...' ({len(chunk)} chars)")

        results = list(qwen3_model.generate(
            text=chunk,
            ref_audio=audio_path,
            ref_text=ref_text or "",
            lang_code=lang_name,
            speed=speed,
            temperature=temperature,
            top_k=top_k,
            top_p=top_p,
            repetition_penalty=repetition_penalty,
            max_tokens=max_tokens,
        ))

        if not results:
            logger.warning(f"  Chunk {i+1} produced no audio, skipping")
            continue

        # Convert MLX array to numpy
        chunk_audio = np.array(results[0].audio, dtype=np.float32)
        if chunk_audio.ndim > 1:
            chunk_audio = chunk_audio.flatten()

        all_audio.append(chunk_audio)

        # Add a small silence gap between chunks (0.15s) for natural pacing
        if i < total_chunks - 1:
            silence = np.zeros(int(sample_rate * 0.15), dtype=np.float32)
            all_audio.append(silence)

    if not all_audio:
        raise ValueError("No audio generated from any chunk")

    # Concatenate all chunks
    audio = np.concatenate(all_audio)

    # Normalize
    max_val = np.max(np.abs(audio))
    if max_val > 0:
        audio = audio / max_val * 0.9

    temp_output = tempfile.mktemp(suffix='.wav')
    sf.write(temp_output, audio, samplerate=sample_rate)

    duration_s = len(audio) / sample_rate
    logger.info(f"Qwen3-TTS done: {total_chunks} chunks -> {duration_s:.1f}s audio "
                f"({os.path.getsize(temp_output)/1024:.1f} KB)")
    return temp_output


def synthesize_with_kokoro(text, voice='af_sarah', speed=1.0):
    """Synthesize with Kokoro TTS via sherpa-onnx - high quality natural voices"""
    import numpy as np
    from scipy.io import wavfile

    logger.info(f"Kokoro synthesizing: '{text[:50]}...' (voice={voice})")

    if not kokoro_tts or not models_loaded.get("kokoro"):
        raise RuntimeError("Kokoro model not loaded")

    if voice not in KOKORO_VOICES:
        available = list(KOKORO_VOICES.keys())
        raise ValueError(f"Voice '{voice}' not found. Available: {', '.join(available)}")

    # Map voice name to speaker ID (index in voices.bin)
    voice_idx = kokoro_voices_list.index(voice) if voice in kokoro_voices_list else 0

    audio = kokoro_tts.generate(text, sid=voice_idx, speed=speed)

    samples = np.array(audio.samples, dtype=np.float32)
    samples_int16 = (samples * 32767).astype(np.int16)

    temp_output = tempfile.mktemp(suffix='.wav')
    wavfile.write(temp_output, audio.sample_rate, samples_int16)

    logger.info(f"Kokoro audio: {os.path.getsize(temp_output)/1024:.1f} KB")
    return temp_output

# ==================== API ROUTES ====================

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    any_loaded = any(models_loaded.values())
    return jsonify({
        'status': 'healthy' if any_loaded else 'loading',
        'models': models_loaded,
        'qwen3_loaded': models_loaded["qwen3"],
        'kokoro_loaded': models_loaded["kokoro"],
        'speakers_count': len(speakers),
    })


@app.route('/clone', methods=['POST'])
def clone_voice():
    """Store reference audio for voice cloning"""
    if 'audio' not in request.files or 'speaker_id' not in request.form:
        return jsonify({'success': False, 'error': 'Missing audio or speaker_id'}), 400

    if not models_loaded["qwen3"]:
        return jsonify({'success': False, 'error': 'Qwen3-TTS model not loaded'}), 503

    audio_file = request.files['audio']
    speaker_id = request.form['speaker_id']

    if not speaker_id or len(speaker_id) > 100:
        return jsonify({'success': False, 'error': 'Invalid speaker_id'}), 400

    try:
        import librosa

        os.makedirs(SPEAKERS_DIR, exist_ok=True)
        audio_path = os.path.join(SPEAKERS_DIR, f"{speaker_id}.wav")
        audio_file.save(audio_path)

        audio, sr = librosa.load(audio_path, sr=22050)
        duration = len(audio) / sr

        if duration < 3.0:
            os.unlink(audio_path)
            return jsonify({'success': False, 'error': f'Audio too short: {duration:.1f}s (minimum 3s)'}), 400
        if duration > 120.0:
            os.unlink(audio_path)
            return jsonify({'success': False, 'error': f'Audio too long: {duration:.1f}s (maximum 120s)'}), 400

        speakers[speaker_id] = {
            'id': speaker_id,
            'audio_path': audio_path,
            'duration': duration
        }

        logger.info(f"Voice cloned: {speaker_id} ({duration:.1f}s)")

        return jsonify({
            'success': True,
            'speaker_id': speaker_id,
            'duration_seconds': duration,
            'message': f'Voice "{speaker_id}" ready for cloning ({duration:.1f}s)'
        })

    except Exception as e:
        logger.error(f"Clone failed: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/qwen3/synthesize', methods=['POST'])
def qwen3_synthesize():
    """Synthesize with Qwen3-TTS voice cloning"""
    if not models_loaded["qwen3"]:
        return jsonify({'error': 'Qwen3-TTS model not loaded'}), 503

    data = request.get_json()
    if not data or 'text' not in data or 'speaker_id' not in data:
        return jsonify({'error': 'Missing text or speaker_id'}), 400

    text = data['text'].strip()
    speaker_id = data['speaker_id']
    language = data.get('language', 'en')
    speed = float(data.get('speed', 1.0))
    temperature = float(data.get('temperature', 0.9))
    top_k = int(data.get('top_k', 50))
    top_p = float(data.get('top_p', 1.0))
    repetition_penalty = float(data.get('repetition_penalty', 1.05))
    max_tokens = int(data.get('max_tokens', 4096))
    ref_text = data.get('ref_text', '')

    if not text:
        return jsonify({'error': 'Text cannot be empty'}), 400
    if speaker_id not in speakers:
        return jsonify({'error': f'Speaker "{speaker_id}" not found'}), 404
    if speed < 0.5 or speed > 2.0:
        return jsonify({'error': 'Speed must be between 0.5 and 2.0'}), 400
    if temperature < 0.0 or temperature > 2.0:
        return jsonify({'error': 'Temperature must be between 0.0 and 2.0'}), 400
    if top_k < 1 or top_k > 200:
        return jsonify({'error': 'Top-K must be between 1 and 200'}), 400
    if top_p < 0.0 or top_p > 1.0:
        return jsonify({'error': 'Top-P must be between 0.0 and 1.0'}), 400

    try:
        output_file = synthesize_with_qwen3(
            text, speakers[speaker_id], language, speed,
            temperature=temperature, top_k=top_k, top_p=top_p,
            repetition_penalty=repetition_penalty, max_tokens=max_tokens,
            ref_text=ref_text,
        )
        response = send_file(output_file, mimetype='audio/wav', as_attachment=False)

        @response.call_on_close
        def cleanup():
            try:
                os.unlink(output_file)
            except Exception:
                pass

        return response

    except Exception as e:
        logger.error(f"Qwen3-TTS synthesis failed: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


# ==================== KOKORO TTS ROUTES ====================

@app.route('/kokoro/synthesize', methods=['POST'])
def kokoro_synthesize():
    """Synthesize with Kokoro TTS - high quality natural voices"""
    if not models_loaded["kokoro"]:
        return jsonify({'error': 'Kokoro model not loaded'}), 503

    data = request.get_json()
    if not data or 'text' not in data:
        return jsonify({'error': 'Missing text'}), 400

    text = data['text'].strip()
    voice = data.get('voice', 'af_sarah')
    speed = float(data.get('speed', 1.0))

    if not text:
        return jsonify({'error': 'Text cannot be empty'}), 400
    if speed < 0.5 or speed > 2.0:
        return jsonify({'error': 'Speed must be between 0.5 and 2.0'}), 400

    try:
        output_file = synthesize_with_kokoro(text, voice, speed)
        response = send_file(output_file, mimetype='audio/wav', as_attachment=False)

        @response.call_on_close
        def cleanup():
            try:
                os.unlink(output_file)
            except Exception:
                pass

        return response

    except ValueError as e:
        return jsonify({'error': str(e)}), 404
    except Exception as e:
        logger.error(f"Kokoro synthesis failed: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/kokoro/voices', methods=['GET'])
def kokoro_voices_endpoint():
    """List available Kokoro voices by language"""
    language = request.args.get('language', None)

    voices_by_lang = {}
    for voice_id, info in KOKORO_VOICES.items():
        lang = info["lang"]
        if language and lang != language:
            continue
        if lang not in voices_by_lang:
            voices_by_lang[lang] = []
        voices_by_lang[lang].append({
            "id": voice_id,
            "name": info["name"],
            "gender": info["gender"],
        })

    if language:
        return jsonify({'language': language, 'voices': voices_by_lang.get(language, [])})
    return jsonify({'voices_by_language': voices_by_lang})


@app.route('/kokoro/languages', methods=['GET'])
def kokoro_languages_endpoint():
    """List available Kokoro languages"""
    return jsonify({'languages': KOKORO_LANGUAGES})


# ==================== SPEAKER MANAGEMENT ====================

@app.route('/speakers', methods=['GET'])
def list_speakers():
    """List all cloned speakers"""
    return jsonify({
        'speakers': [
            {'id': s['id'], 'duration': s['duration']}
            for s in speakers.values()
        ],
        'count': len(speakers)
    })


@app.route('/speakers/<speaker_id>', methods=['DELETE'])
def delete_speaker(speaker_id):
    """Delete a cloned speaker"""
    if speaker_id not in speakers:
        return jsonify({'error': 'Speaker not found'}), 404

    audio_path = speakers[speaker_id].get('audio_path')
    if audio_path and os.path.exists(audio_path):
        try:
            os.unlink(audio_path)
        except Exception as e:
            logger.warning(f"Could not delete audio file: {e}")

    del speakers[speaker_id]
    logger.info(f"Deleted speaker: {speaker_id}")
    return jsonify({'message': f'Deleted {speaker_id}'})


@app.route('/speakers/<speaker_id>/rename', methods=['POST'])
def rename_speaker(speaker_id):
    """Rename a cloned speaker"""
    if speaker_id not in speakers:
        return jsonify({'error': 'Speaker not found'}), 404

    data = request.get_json()
    new_name = data.get('new_name', '').strip()

    if not new_name:
        return jsonify({'error': 'New name is required'}), 400

    import re
    new_name = re.sub(r'[<>:"/\\|?*]', '', new_name)[:50]

    if new_name in speakers:
        return jsonify({'error': f'Name "{new_name}" already exists'}), 400

    old_data = speakers[speaker_id]
    old_audio_path = old_data['audio_path']
    new_audio_path = os.path.join(SPEAKERS_DIR, f"{new_name}.wav")

    try:
        os.rename(old_audio_path, new_audio_path)
        speakers[new_name] = {
            'id': new_name,
            'audio_path': new_audio_path,
            'duration': old_data['duration']
        }
        del speakers[speaker_id]

        logger.info(f"Renamed speaker: {speaker_id} -> {new_name}")
        return jsonify({'success': True, 'old_name': speaker_id, 'new_name': new_name})

    except Exception as e:
        logger.error(f"Rename failed: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/shutdown', methods=['POST'])
def shutdown():
    """Gracefully shutdown the server"""
    logger.info("Shutdown requested")
    func = request.environ.get('werkzeug.server.shutdown')
    if func:
        func()
    return jsonify({'message': 'Shutting down'})


# ==================== MAIN ====================

def load_models_async():
    """Load models in background thread"""
    load_qwen3_model()
    load_kokoro_model()
    load_speakers_from_disk()


if __name__ == '__main__':
    print("=" * 50)
    print("  EchoCore Pro TTS Server")
    print("  Qwen3-TTS (Voice Cloning) + Kokoro (Natural TTS)")
    print("=" * 50)

    loader_thread = threading.Thread(target=load_models_async, daemon=True)
    loader_thread.start()

    print("  Server starting on http://127.0.0.1:8765")
    print("  Models loading in background...")
    print("=" * 50)

    app.run(host='127.0.0.1', port=8765, debug=False, threaded=True)

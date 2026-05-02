#!/usr/bin/env python3
"""
EchoCore Pro local backend.

Runs only on 127.0.0.1. Models are loaded from the app bundle:
- Voxtral 4B MLX 4bit for English/Italian TTS
- Piper sl_SI-artur-medium for Slovenian TTS
- Whisper small MLX q4 for STT
"""

from __future__ import annotations

import os
import subprocess
import tempfile
import threading
import time
import traceback
from pathlib import Path


def configure_stdio() -> None:
    log_file = os.environ.get("ECHOCORE_LOG_FILE")
    if not log_file:
        return

    try:
        Path(log_file).parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(log_file, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
        os.dup2(fd, 1)
        os.dup2(fd, 2)
        if fd > 2:
            os.close(fd)
    except OSError:
        pass


configure_stdio()

import numpy as np
import soundfile as sf
from flask import Flask, after_this_request, jsonify, request, send_file


START_TIME = time.time()
ROOT = Path(os.environ.get("ECHOCORE_MODEL_ROOT", Path(__file__).resolve().parents[1] / "Models"))
PARENT_PID = int(os.environ.get("ECHOCORE_PARENT_PID", "0") or "0")
VOXTRAL_DIR = ROOT / "Voxtral"
WHISPER_DIR = ROOT / "WhisperSmallQ4"
PIPER_DIR = ROOT / "Piper" / "sl" / "sl_SI" / "artur" / "medium"
PIPER_MODEL = PIPER_DIR / "sl_SI-artur-medium.onnx"
PIPER_CONFIG = PIPER_DIR / "sl_SI-artur-medium.onnx.json"

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 250 * 1024 * 1024

voxtral_model = None
voxtral_load_lock = threading.Lock()
voxtral_generate_lock = threading.Lock()
piper_lock = threading.Lock()
stt_lock = threading.Lock()

VOICE_CATALOG = {
    "English": ["casual_female", "casual_male", "cheerful_female", "neutral_female", "neutral_male"],
    "Italian": ["it_female", "it_male"],
    "German": ["de_female", "de_male"],
    "Spanish": ["es_female", "es_male"],
    "French": ["fr_female", "fr_male"],
    "Hindi": ["hi_female", "hi_male"],
    "Dutch": ["nl_female", "nl_male"],
    "Portuguese": ["pt_female", "pt_male"],
    "Arabic": ["ar_male"],
    "Slovenian": ["sl_SI-artur-medium"],
}
VOXTRAL_LANGUAGE_DEFAULTS = {
    "en": "casual_female",
    "it": "it_female",
    "de": "de_female",
    "es": "es_female",
    "fr": "fr_female",
    "hi": "hi_female",
    "nl": "nl_female",
    "pt": "pt_female",
    "ar": "ar_male",
}
VOXTRAL_VOICES = {
    voice
    for language, voices in VOICE_CATALOG.items()
    if language != "Slovenian"
    for voice in voices
}


def voice_file_exists(voice: str) -> bool:
    return (VOXTRAL_DIR / "voice_embedding" / f"{voice}.safetensors").exists()


def available_voices() -> dict[str, list[str]]:
    catalog: dict[str, list[str]] = {}
    for language, voices in VOICE_CATALOG.items():
        if language == "Slovenian":
            if PIPER_MODEL.exists() and PIPER_CONFIG.exists():
                catalog[language] = voices
            continue

        existing = [voice for voice in voices if voice_file_exists(voice)]
        if existing:
            catalog[language] = existing
    return catalog


def voice_status() -> dict[str, bool]:
    return {voice: voice_file_exists(voice) for voice in sorted(VOXTRAL_VOICES)}


def monitor_parent() -> None:
    if PARENT_PID <= 1:
        return

    while True:
        time.sleep(2)
        if os.getppid() == 1:
            print("EchoCore Pro backend exiting because parent app is gone.", flush=True)
            os._exit(0)
        try:
            os.kill(PARENT_PID, 0)
        except OSError:
            print("EchoCore Pro backend exiting because parent app PID is no longer alive.", flush=True)
            os._exit(0)


threading.Thread(target=monitor_parent, daemon=True).start()


def chunk_text(text: str, limit: int = 300) -> list[str]:
    text = " ".join(text.strip().split())
    if not text:
        return []
    if len(text) <= limit:
        return [text]

    chunks: list[str] = []
    current = ""
    for part in text.replace("!", ".").replace("?", ".").split("."):
        sentence = part.strip()
        if not sentence:
            continue
        sentence = sentence + "."
        if current and len(current) + len(sentence) + 1 > limit:
            chunks.append(current)
            current = sentence
        else:
            current = f"{current} {sentence}".strip() if current else sentence
    if current:
        chunks.append(current)
    return chunks


def fallback_voice(language: str, voice: str) -> str:
    default = VOXTRAL_LANGUAGE_DEFAULTS.get(language, "casual_female")

    if not voice or voice not in VOXTRAL_VOICES:
        print(f"Using fallback Voxtral voice '{default}' for requested voice '{voice}'.", flush=True)
        return default
    return voice


def load_voxtral():
    global voxtral_model
    if voxtral_model is not None:
        return voxtral_model
    with voxtral_load_lock:
        if voxtral_model is not None:
            return voxtral_model
        from mlx_audio.tts.utils import load

        voxtral_model = load(str(VOXTRAL_DIR))
    return voxtral_model


def synthesize_voxtral(text: str, voice: str) -> Path:
    model = load_voxtral()
    sample_rate = 24000
    pieces: list[np.ndarray] = []
    chunks = chunk_text(text)

    with voxtral_generate_lock:
        for index, chunk in enumerate(chunks):
            max_tokens = min(1536, max(256, len(chunk) * 9))
            results = list(model.generate(text=chunk, voice=voice, max_tokens=max_tokens))
            for result in results:
                sample_rate = int(getattr(result, "sample_rate", sample_rate) or sample_rate)
                audio = np.array(result.audio, dtype=np.float32).reshape(-1)
                pieces.append(audio)
            if index < len(chunks) - 1:
                pieces.append(np.zeros(int(sample_rate * 0.12), dtype=np.float32))

    if not pieces:
        raise RuntimeError("No audio generated")

    audio = np.concatenate(pieces)
    peak = float(np.max(np.abs(audio))) if len(audio) else 0
    if peak > 0:
        audio = audio / peak * 0.92

    fd, output_name = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    output = Path(output_name)
    sf.write(output, audio, sample_rate)
    return output


def synthesize_piper(text: str, speed: float) -> Path:
    if not PIPER_MODEL.exists() or not PIPER_CONFIG.exists():
        raise FileNotFoundError("Bundled Slovenian Piper voice is missing")

    fd, output_name = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    output = Path(output_name)
    length_scale = max(0.65, min(1.45, 1.0 / speed))
    command = [
        os.environ.get("ECHOCORE_PYTHON", os.sys.executable),
        "-m",
        "piper",
        "-m",
        str(PIPER_MODEL),
        "-c",
        str(PIPER_CONFIG),
        "-f",
        str(output),
        "--length-scale",
        f"{length_scale:.2f}",
    ]
    try:
        with piper_lock:
            subprocess.run(command, input=text, text=True, check=True)
    except Exception:
        try:
            output.unlink()
        except OSError:
            pass
        raise
    return output


def remove_after_send(path: Path):
    @after_this_request
    def cleanup(response):
        try:
            path.unlink()
        except OSError:
            pass
        return response


def model_status() -> dict[str, dict[str, bool]]:
    return {
        "voxtral": {
            "directory": VOXTRAL_DIR.exists(),
            "config": (VOXTRAL_DIR / "config.json").exists(),
            "weights": (VOXTRAL_DIR / "model.safetensors").exists(),
            "voices": (VOXTRAL_DIR / "voice_embedding").exists(),
            "all_advertised_voice_files": all(voice_status().values()),
        },
        "piper_slovenian": {
            "model": PIPER_MODEL.exists(),
            "config": PIPER_CONFIG.exists(),
        },
        "whisper": {
            "directory": WHISPER_DIR.exists(),
            "config": (WHISPER_DIR / "config.json").exists(),
            "weights": (WHISPER_DIR / "weights.npz").exists(),
        },
    }


def models_ready() -> bool:
    statuses = model_status()
    return all(all(checks.values()) for checks in statuses.values())


@app.get("/health")
def health():
    ready = models_ready()
    return jsonify(
        {
            "status": "ready" if ready else "degraded",
            "ready": ready,
            "voxtral_loaded": voxtral_model is not None,
            "stt_ready": (WHISPER_DIR / "config.json").exists() and (WHISPER_DIR / "weights.npz").exists(),
            "models_ready": ready,
            "model_status": model_status(),
            "voice_status": voice_status(),
            "models_root": str(ROOT),
            "uptime_seconds": round(time.time() - START_TIME, 1),
            "server_pid": os.getpid(),
            "parent_pid": os.getppid(),
        }
    )


@app.get("/voices")
def voices():
    return jsonify({"voices_by_language": available_voices()})


@app.post("/tts")
def tts():
    payload = request.get_json(silent=True) or {}
    text = str(payload.get("text", "")).strip()
    language = str(payload.get("language", "en"))
    voice = str(payload.get("voice", "casual_female"))
    speed = float(payload.get("speed", 1.0))

    if not text:
        return jsonify({"error": "Text is required"}), 400
    if len(text) > 8_000:
        return jsonify({"error": "Text is too long. Keep each request under 8,000 characters."}), 413

    try:
        started = time.time()
        if language == "sl":
            output = synthesize_piper(text, speed)
        else:
            voice = fallback_voice(language, voice)
            output = synthesize_voxtral(text, voice)
        print(
            f"TTS ok language={language} voice={voice} chars={len(text)} elapsed={time.time() - started:.1f}s",
            flush=True,
        )
        remove_after_send(output)
        return send_file(output, mimetype="audio/wav")
    except Exception as error:
        print(f"TTS failed language={language} voice={voice} chars={len(text)}: {error}", flush=True)
        traceback.print_exc()
        return jsonify({"error": str(error)}), 500


@app.post("/stt")
def stt():
    if "audio" not in request.files:
        return jsonify({"error": "Audio file is required"}), 400

    suffix = Path(request.files["audio"].filename or "audio.wav").suffix or ".wav"
    fd, input_name = tempfile.mkstemp(suffix=suffix)
    os.close(fd)
    input_path = Path(input_name)
    request.files["audio"].save(input_path)

    try:
        import mlx_whisper

        with stt_lock:
            result = mlx_whisper.transcribe(str(input_path), path_or_hf_repo=str(WHISPER_DIR))
        return jsonify(
            {
                "text": result.get("text", "").strip(),
                "language": result.get("language"),
                "duration_seconds": None,
            }
        )
    except Exception as error:
        return jsonify({"error": str(error)}), 500
    finally:
        try:
            input_path.unlink()
        except OSError:
            pass


if __name__ == "__main__":
    print(f"EchoCore Pro backend using models: {ROOT}", flush=True)
    app.run(host="127.0.0.1", port=8765, debug=False, threaded=True)

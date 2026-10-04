#!/usr/bin/env python3
"""
EchoCore Pro - Linux & Cross-Platform Audio Intelligence Server
FastAPI backend powering Voice Cloning, ElevenLabs, x.ai, OpenRouter, and Local Piper TTS.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import time
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional

import httpx
import soundfile as sf
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel, Field

APP_DIR = Path(__file__).resolve().parent.parent
MODELS_DIR = APP_DIR / "Models"
DATA_DIR = Path(os.environ.get("ECHOCORE_DATA_DIR", Path.home() / ".config" / "echocore"))
CONFIG_FILE = DATA_DIR / "config.json"
HISTORY_FILE = DATA_DIR / "history.json"
CLONES_DIR = DATA_DIR / "clones"
AUDIO_DIR = DATA_DIR / "audio_cache"

for directory in (DATA_DIR, CLONES_DIR, AUDIO_DIR):
    directory.mkdir(parents=True, exist_ok=True)

DEFAULT_CONFIG: Dict[str, Any] = {
    "elevenlabs_api_key": os.environ.get("ELEVENLABS_API_KEY", ""),
    "xai_api_key": os.environ.get("XAI_API_KEY", ""),
    "openrouter_api_key": os.environ.get("OPENROUTER_API_KEY", ""),
    "default_provider": "elevenlabs",
    "elevenlabs_model": "eleven_multilingual_v2",
    "xai_model": "grok-4.20-non-reasoning",
    "openrouter_model": "openai/gpt-4o-mini",
    "speed": 1.0,
    "stability": 0.5,
    "similarity_boost": 0.75,
    "style": 0.0,
}


def load_config() -> Dict[str, Any]:
    if not CONFIG_FILE.exists():
        save_config(DEFAULT_CONFIG)
        return DEFAULT_CONFIG.copy()
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            merged = DEFAULT_CONFIG.copy()
            merged.update(data)
            return merged
    except Exception as exc:
        print(f"Error loading config: {exc}", flush=True)
        return DEFAULT_CONFIG.copy()


def save_config(config: Dict[str, Any]) -> None:
    try:
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=2)
    except Exception as exc:
        print(f"Error saving config: {exc}", flush=True)


def load_history() -> List[Dict[str, Any]]:
    if not HISTORY_FILE.exists():
        return []
    try:
        with open(HISTORY_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as exc:
        print(f"Error loading history: {exc}", flush=True)
        return []


def save_history(history: List[Dict[str, Any]]) -> None:
    try:
        with open(HISTORY_FILE, "w", encoding="utf-8") as f:
            json.dump(history, f, indent=2)
    except Exception as exc:
        print(f"Error saving history: {exc}", flush=True)


def add_history_entry(entry: Dict[str, Any]) -> None:
    history = load_history()
    history.insert(0, entry)
    history = history[:100]  # keep last 100
    save_history(history)


app = FastAPI(title="EchoCore Pro Engine", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_local_piper_models() -> List[Dict[str, Any]]:
    piper_voices: List[Dict[str, Any]] = []
    piper_base = MODELS_DIR / "Piper"
    if not piper_base.exists():
        return piper_voices

    for onnx_path in piper_base.glob("**/*.onnx"):
        json_path = onnx_path.with_name(f"{onnx_path.name}.json")
        if not json_path.exists():
            continue

        voice_id = f"local-piper-{onnx_path.stem}"
        name = onnx_path.stem.replace("-medium", "").replace("-", " ").title()
        language = "en"
        if "sl_SI" in onnx_path.stem or "sl" in str(onnx_path):
            language = "sl"
            name = f"Slovenian ({onnx_path.stem})"

        piper_voices.append(
            {
                "id": voice_id,
                "name": name,
                "provider": "local",
                "category": "local",
                "language": language,
                "model_path": str(onnx_path),
                "config_path": str(json_path),
                "description": f"Local offline Piper neural voice ({onnx_path.stem})",
            }
        )
    return piper_voices


def get_local_clones() -> List[Dict[str, Any]]:
    clones: List[Dict[str, Any]] = []
    metadata_file = CLONES_DIR / "clones.json"
    if metadata_file.exists():
        try:
            with open(metadata_file, "r", encoding="utf-8") as f:
                clones = json.load(f)
        except Exception:
            pass
    return clones


def save_local_clones(clones: List[Dict[str, Any]]) -> None:
    metadata_file = CLONES_DIR / "clones.json"
    with open(metadata_file, "w", encoding="utf-8") as f:
        json.dump(clones, f, indent=2)


@app.get("/api/health")
async def health():
    cfg = load_config()
    piper_models = get_local_piper_models()
    return {
        "status": "online",
        "platform": "linux",
        "piper_models_count": len(piper_models),
        "elevenlabs_configured": bool(cfg.get("elevenlabs_api_key")),
        "xai_configured": bool(cfg.get("xai_api_key")),
        "openrouter_configured": bool(cfg.get("openrouter_api_key")),
        "audio_dir": str(AUDIO_DIR),
        "data_dir": str(DATA_DIR),
        "uptime": round(time.time() - SERVER_START_TIME, 1),
    }


@app.get("/api/config")
async def get_config():
    cfg = load_config()
    # Mask keys for security in UI display
    masked = cfg.copy()
    for k in ("elevenlabs_api_key", "xai_api_key", "openrouter_api_key"):
        val = str(masked.get(k, "") or "")
        if val:
            masked[f"{k}_masked"] = f"{val[:4]}...{val[-4:]}" if len(val) > 8 else "***"
        else:
            masked[f"{k}_masked"] = ""
    return masked


class ConfigUpdate(BaseModel):
    elevenlabs_api_key: Optional[str] = None
    xai_api_key: Optional[str] = None
    openrouter_api_key: Optional[str] = None
    default_provider: Optional[str] = None
    elevenlabs_model: Optional[str] = None
    xai_model: Optional[str] = None
    openrouter_model: Optional[str] = None
    speed: Optional[float] = None
    stability: Optional[float] = None
    similarity_boost: Optional[float] = None
    style: Optional[float] = None


@app.post("/api/config")
async def update_config(update: ConfigUpdate):
    cfg = load_config()
    update_dict = update.model_dump(exclude_unset=True)
    for k, v in update_dict.items():
        if v is not None:
            cfg[k] = v
    save_config(cfg)
    return {"status": "ok", "message": "Configuration saved successfully"}


@app.get("/api/voices")
async def get_voices():
    cfg = load_config()
    voices: List[Dict[str, Any]] = []

    # 1. Local Piper Voices
    local_voices = get_local_piper_models()
    voices.extend(local_voices)

    # 2. Local Cloned Voice Profiles
    local_clones = get_local_clones()
    voices.extend(local_clones)

    # 3. ElevenLabs Voices (if key configured)
    api_key = cfg.get("elevenlabs_api_key")
    if api_key:
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.get(
                    "https://api.elevenlabs.io/v1/voices",
                    headers={"xi-api-key": api_key},
                )
                if res.status_code == 200:
                    data = res.json()
                    for v in data.get("voices", []):
                        category = v.get("category", "premade")
                        # Tag cloned voices explicitly
                        is_cloned = category in ("cloned", "generated", "professional")
                        voices.append(
                            {
                                "id": v.get("voice_id"),
                                "name": v.get("name"),
                                "provider": "elevenlabs",
                                "category": "cloned" if is_cloned else "premade",
                                "labels": v.get("labels", {}),
                                "preview_url": v.get("preview_url"),
                                "description": v.get("description")
                                or (f"ElevenLabs Cloned Voice" if is_cloned else "ElevenLabs Stock Voice"),
                            }
                        )
        except Exception as exc:
            print(f"Warning: Failed to fetch ElevenLabs voices: {exc}", flush=True)

    return {"voices": voices}


@app.post("/api/clone")
async def clone_voice(
    name: str = Form(...),
    description: str = Form(""),
    provider: str = Form("elevenlabs"),
    file: UploadFile = File(...),
):
    cfg = load_config()
    content = await file.read()
    if len(content) == 0:
        raise HTTPException(status_code=400, detail="Uploaded audio file is empty.")

    original_filename = file.filename or "sample.wav"
    suffix = Path(original_filename).suffix or ".wav"
    clone_id = f"clone-{uuid.uuid4().hex[:8]}"

    # Save audio sample locally
    saved_sample_path = CLONES_DIR / f"{clone_id}{suffix}"
    with open(saved_sample_path, "wb") as f:
        f.write(content)

    eleven_key = cfg.get("elevenlabs_api_key")

    if provider == "elevenlabs" and eleven_key:
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                files = {
                    "files": (original_filename, content, file.content_type or "audio/wav"),
                }
                data = {
                    "name": name,
                    "description": description or f"Cloned via EchoCore Pro on {time.strftime('%Y-%m-%d %H:%M')}",
                }
                res = await client.post(
                    "https://api.elevenlabs.io/v1/voices/add",
                    headers={"xi-api-key": eleven_key},
                    files=files,
                    data=data,
                )
                if res.status_code != 200:
                    err_msg = res.text
                    try:
                        err_json = res.json()
                        err_msg = err_json.get("detail", {}).get("message", res.text)
                    except Exception:
                        pass
                    raise HTTPException(
                        status_code=res.status_code,
                        detail=f"ElevenLabs Voice Cloning error: {err_msg}",
                    )

                voice_info = res.json()
                remote_id = voice_info.get("voice_id")
                return {
                    "status": "ok",
                    "voice_id": remote_id,
                    "name": name,
                    "provider": "elevenlabs",
                    "category": "cloned",
                    "description": description,
                    "local_sample": str(saved_sample_path),
                }
        except httpx.HTTPError as exc:
            raise HTTPException(status_code=502, detail=f"Network error contacting ElevenLabs: {exc}")

    # Fallback or local clone register
    clones = get_local_clones()
    clone_entry = {
        "id": clone_id,
        "name": name,
        "provider": "local",
        "category": "cloned",
        "description": description or "Local reference voice profile",
        "sample_path": str(saved_sample_path),
        "created_at": time.time(),
    }
    clones.insert(0, clone_entry)
    save_local_clones(clones)

    return {
        "status": "ok",
        "voice_id": clone_id,
        "name": name,
        "provider": "local",
        "category": "cloned",
        "description": description,
        "sample_path": str(saved_sample_path),
    }


@app.delete("/api/voices/{voice_id}")
async def delete_voice(voice_id: str):
    cfg = load_config()

    # Check local clones first
    local_clones = get_local_clones()
    filtered = [c for c in local_clones if c.get("id") != voice_id]
    if len(filtered) != len(local_clones):
        save_local_clones(filtered)
        return {"status": "ok", "message": "Local cloned voice removed"}

    # ElevenLabs remote voice deletion
    eleven_key = cfg.get("elevenlabs_api_key")
    if eleven_key:
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.delete(
                    f"https://api.elevenlabs.io/v1/voices/{voice_id}",
                    headers={"xi-api-key": eleven_key},
                )
                if res.status_code == 200:
                    return {"status": "ok", "message": "ElevenLabs cloned voice deleted"}
        except Exception as exc:
            raise HTTPException(status_code=500, detail=str(exc))

    return {"status": "ok", "message": "Voice removed"}


class TTSRequest(BaseModel):
    text: str = Field(..., max_length=10000)
    voice_id: str
    provider: Optional[str] = "elevenlabs"
    model_id: Optional[str] = "eleven_multilingual_v2"
    speed: Optional[float] = 1.0
    stability: Optional[float] = 0.5
    similarity_boost: Optional[float] = 0.75
    style: Optional[float] = 0.0


@app.post("/api/tts")
async def generate_tts(req: TTSRequest):
    text = req.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text cannot be empty.")

    cfg = load_config()
    provider = req.provider or cfg.get("default_provider", "elevenlabs")
    voice_id = req.voice_id

    # Auto-detect provider if voice_id starts with local-piper-
    if voice_id.startswith("local-piper-") or provider == "local":
        return await synthesize_local_piper(text, voice_id, req.speed or 1.0)

    # ElevenLabs route
    if provider == "elevenlabs":
        api_key = cfg.get("elevenlabs_api_key")
        if not api_key:
            raise HTTPException(
                status_code=400,
                detail="ElevenLabs API Key is not configured. Please set it in Settings or select the Local Piper voice.",
            )
        return await synthesize_elevenlabs(
            text=text,
            voice_id=voice_id,
            api_key=api_key,
            model_id=req.model_id or cfg.get("elevenlabs_model", "eleven_multilingual_v2"),
            stability=req.stability if req.stability is not None else cfg.get("stability", 0.5),
            similarity_boost=req.similarity_boost
            if req.similarity_boost is not None
            else cfg.get("similarity_boost", 0.75),
            style=req.style if req.style is not None else cfg.get("style", 0.0),
        )

    raise HTTPException(status_code=400, detail=f"Unsupported provider: {provider}")


async def synthesize_local_piper(text: str, voice_id: str, speed: float) -> Dict[str, Any]:
    models = get_local_piper_models()
    matched = None
    for m in models:
        if m["id"] == voice_id:
            matched = m
            break

    # If no exact match, fallback to first available
    if not matched and models:
        matched = models[0]

    if not matched:
        raise HTTPException(
            status_code=404,
            detail="No local Piper ONNX models found in Models/Piper.",
        )

    output_filename = f"render_{uuid.uuid4().hex[:10]}.wav"
    output_path = AUDIO_DIR / output_filename

    length_scale = max(0.5, min(2.0, 1.0 / max(0.2, speed)))
    python_bin = APP_DIR / ".venv-linux" / "bin" / "piper"
    if not python_bin.exists():
        python_bin = Path(shutil.which("piper") or "piper")

    command = [
        str(python_bin),
        "-m",
        matched["model_path"],
        "-c",
        matched["config_path"],
        "-f",
        str(output_path),
        "--length-scale",
        f"{length_scale:.2f}",
    ]

    started = time.time()
    try:
        proc = subprocess.run(command, input=text, text=True, capture_output=True, check=True)
    except subprocess.CalledProcessError as exc:
        print(f"Piper error: {exc.stderr}", flush=True)
        raise HTTPException(status_code=500, detail=f"Local Piper synthesis failed: {exc.stderr}")

    duration = 0.0
    try:
        data, sr = sf.read(str(output_path))
        duration = round(len(data) / sr, 2)
    except Exception:
        pass

    elapsed = round(time.time() - started, 2)
    history_entry = {
        "id": uuid.uuid4().hex[:12],
        "filename": output_filename,
        "audio_url": f"/api/audio/{output_filename}",
        "text": text,
        "voice_name": matched["name"],
        "provider": "Local Piper",
        "duration": duration,
        "elapsed": elapsed,
        "timestamp": time.time(),
    }
    add_history_entry(history_entry)

    return history_entry


async def synthesize_elevenlabs(
    text: str,
    voice_id: str,
    api_key: str,
    model_id: str,
    stability: float,
    similarity_boost: float,
    style: float,
) -> Dict[str, Any]:
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
    payload = {
        "text": text,
        "model_id": model_id,
        "voice_settings": {
            "stability": float(stability),
            "similarity_boost": float(similarity_boost),
            "style": float(style),
            "use_speaker_boost": True,
        },
    }

    started = time.time()
    try:
        async with httpx.AsyncClient(timeout=45.0) as client:
            res = await client.post(
                url,
                headers={
                    "xi-api-key": api_key,
                    "Content-Type": "application/json",
                    "Accept": "audio/mpeg",
                },
                json=payload,
            )
            if res.status_code != 200:
                err_text = res.text
                try:
                    err_json = res.json()
                    err_text = err_json.get("detail", {}).get("message", res.text)
                except Exception:
                    pass
                raise HTTPException(
                    status_code=res.status_code,
                    detail=f"ElevenLabs TTS failed: {err_text}",
                )

            output_filename = f"render_{uuid.uuid4().hex[:10]}.mp3"
            output_path = AUDIO_DIR / output_filename
            with open(output_path, "wb") as f:
                f.write(res.content)

    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"ElevenLabs connection failed: {exc}")

    elapsed = round(time.time() - started, 2)
    duration = 0.0
    try:
        data, sr = sf.read(str(output_path))
        duration = round(len(data) / sr, 2)
    except Exception:
        # Estimate ~150 words per minute if header read fails
        duration = round(max(1.0, len(text.split()) / 2.5), 1)

    history_entry = {
        "id": uuid.uuid4().hex[:12],
        "filename": output_filename,
        "audio_url": f"/api/audio/{output_filename}",
        "text": text,
        "voice_name": f"ElevenLabs ({voice_id[:6]}...)",
        "provider": "ElevenLabs",
        "duration": duration,
        "elapsed": elapsed,
        "timestamp": time.time(),
    }
    add_history_entry(history_entry)

    return history_entry


class EnhanceRequest(BaseModel):
    text: str
    provider: Optional[str] = "xai"
    mode: Optional[str] = "polish"
    custom_instruction: Optional[str] = None


@app.post("/api/ai/enhance")
async def enhance_script(req: EnhanceRequest):
    text = req.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text cannot be empty.")

    cfg = load_config()
    provider = req.provider or "xai"

    system_prompts = {
        "polish": "You are a professional voiceover editor. Polish the text for natural spoken delivery, ideal cadence, and clear pronunciation. Return ONLY the polished script, no explanations or introductory remarks.",
        "dramatic": "You are a cinematic narration writer. Re-write the given text to have high dramatic tension, cinematic rhythm, and impactful spoken pacing. Return ONLY the dramatic script.",
        "podcast": "You are a charismatic, conversational podcast host. Make the script feel warm, engaging, lively, and effortless to speak aloud. Return ONLY the podcast script.",
        "expand": "You are a creative voice script writer. Expand upon this idea into a complete, captivating 3-paragraph spoken audio monologue. Return ONLY the script.",
    }

    system_instruction = system_prompts.get(req.mode or "polish", system_prompts["polish"])
    if req.custom_instruction:
        system_instruction += f"\nAdditional direction: {req.custom_instruction}"

    if provider == "xai":
        api_key = cfg.get("xai_api_key")
        if not api_key:
            raise HTTPException(
                status_code=400,
                detail="x.ai API key is missing. Please add your x.ai API key in Settings.",
            )
        model = cfg.get("xai_model", "grok-2-latest")
        endpoint = "https://api.x.ai/v1/chat/completions"
        headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    elif provider == "openrouter":
        api_key = cfg.get("openrouter_api_key")
        if not api_key:
            raise HTTPException(
                status_code=400,
                detail="OpenRouter API key is missing. Please add your OpenRouter API key in Settings.",
            )
        model = cfg.get("openrouter_model", "openai/gpt-4o-mini")
        endpoint = "https://openrouter.ai/api/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "HTTP-Referer": "https://echocore.pro",
            "X-Title": "EchoCore Pro",
            "Content-Type": "application/json",
        }
    else:
        raise HTTPException(status_code=400, detail=f"Unsupported AI provider: {provider}")

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            res = await client.post(
                endpoint,
                headers=headers,
                json={
                    "model": model,
                    "messages": [
                        {"role": "system", "content": system_instruction},
                        {"role": "user", "content": text},
                    ],
                    "temperature": 0.7,
                },
            )
            if res.status_code != 200:
                raise HTTPException(status_code=res.status_code, detail=f"AI generation failed: {res.text}")
            data = res.json()
            enhanced = data["choices"][0]["message"]["content"].strip()
            return {"enhanced_text": enhanced, "provider": provider, "model": model}
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Failed to connect to {provider}: {exc}")


@app.get("/api/audio/{filename}")
@app.head("/api/audio/{filename}")
async def get_audio_file(filename: str):
    file_path = AUDIO_DIR / filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Audio file not found.")
    media_type = "audio/wav" if file_path.suffix == ".wav" else "audio/mpeg"
    return FileResponse(file_path, media_type=media_type, filename=filename)


@app.get("/api/history")
async def get_history():
    return {"history": load_history()}


@app.delete("/api/history/{history_id}")
async def delete_history_item(history_id: str):
    history = load_history()
    target = None
    remaining = []
    for item in history:
        if item.get("id") == history_id:
            target = item
        else:
            remaining.append(item)

    if target:
        filename = target.get("filename")
        if filename:
            file_path = AUDIO_DIR / filename
            if file_path.exists():
                try:
                    file_path.unlink()
                except OSError:
                    pass
        save_history(remaining)
        return {"status": "ok", "message": "History item deleted"}

    return {"status": "not_found", "message": "Item not found"}


SERVER_START_TIME = time.time()

if __name__ == "__main__":
    import uvicorn

    print("Starting EchoCore Pro engine on http://127.0.0.1:8765...", flush=True)
    uvicorn.run("main:app", host="127.0.0.1", port=8765, reload=False, app_dir=str(APP_DIR / "server"))

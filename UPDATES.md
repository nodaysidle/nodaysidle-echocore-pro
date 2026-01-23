# Updates

## Code Reference

Here’s a compact blueprint you can follow to implement the whole thing.

1. High‑level structure of the app

You already have the main sections; refine them like this:

- Models:
Central “inventory” of all models (what’s installed, size, type, active backend).

- Recording:
Record microphone input to WAV, optionally run STT (Whisper/Seamless) on it.

- Voice Cloning:
Take a reference WAV, create a cloned voice (speaker/profile) using a cloning model.

- TTS (new section between Voice Cloning and Processing):
Turn text into speech using:

 ▫ Cloned voices (from XTTS / OpenVoice / VALL‑E X), and

 ▫ Preset model voices (SpeechT5, Bark).

- Processing / History:
Post‑processing, effects, normalization, list of generated clips, etc.

2. How each model fits

Use the “Type” you show on the Models page as the source of truth:

Speech to Text (STT)

- Whisper family (Tiny/Base/Small/Medium).

- SeamlessM4T.

→ Used in Recording and anywhere you need transcription.

Text to Speech (TTS – preset voices)

- Bark Small.

- SpeechT5 TTS.

→ Used in the TTS section, no cloning step required:

- They can generate audio with no user WAV.

- They act as “preset/model voices”.

Voice Cloning

- XTTS v2 (Voice Cloning).

- OpenVoice (Zero‑Shot Clone).

- VALL‑E X (Multilingual Clone).

→ Used in Voice Cloning:

- Upload/record 6–60s WAV.

- Call clone_voice /clone with the chosen backend.

- Store a speaker_id (and any extra metadata) in your server.

Then those cloned voices appear as selectable speakers in the TTS section.

3. Responsibilities per section

Models

- Show installed vs downloadable models (your screenshot already does this).

- For each “type”, allow choosing the active backend:

 ▫ STT backend (e.g. Whisper Small vs Base).

 ▫ Cloning backend (XTTS vs OpenVoice vs VALL‑E X).

 ▫ TTS backend (SpeechT5 vs Bark vs XTTS with a default voice if you want).

The active choices here inform what Recording / Voice Cloning / TTS use by default.

Recording

- Input: mic.

- Output: WAV.

- Optional: run STT (Whisper/Seamless) to get text and store both WAV + transcript.

This WAV is what you can feed into Voice Cloning or keep in History.

Voice Cloning

- Backend: any Voice Cloning model from Models:

 ▫ XTTS v2

 ▫ OpenVoice

 ▫ VALL‑E X

 ▫ (OpenVoice routing already exists in your Python.)

- UI:

 ▫ Upload or record 6–60s WAV.

 ▫ Click “Clone Voice” → clone_voice/clone.

 ▫ Show resulting cloned speaker_id (like d4aac367), “Use This Voice,” “Delete,” etc.

- Internals:

 ▫ speakers[speaker_id]['audio_path'] = path_to_wav (you already do this).

 ▫ For OpenVoice/VALL‑E X you may also add embeddings or prompt metadata later.

TTS (new section)

This is where everything for text → audio lives.

- Inputs:

 ▫ Text.

 ▫ Language.

 ▫ Speed and advanced sliders (temperature, top_p, repetition, etc.).

 ▫ Voice selection:

 ⁃ Cloned voices: entries from speakers (XTTS/OpenVoice/VALL‑E X).

 ⁃ Preset voices: fixed options for SpeechT5 and Bark.

- Backends:

 ▫ If user selects a cloned speaker with XTTS/OpenVoice/VALL‑E X → call synthesize_audio with that speaker_id and appropriate language (it already routes to synthesize_with_xtts, synthesize_with_openvoice, synthesize_with_vallex).

 ▫ If user selects SpeechT5 default voice:

 ⁃ Call synthesize_with_speecht5 with a pseudo‑speaker like "speecht5_default" that doesn’t require a WAV (your code already uses a default CMU Arctic embedding when none is present).

 ▫ If user selects Bark preset:

 ⁃ Call synthesize_with_bark with a speaker_data dict containing bark_preset (e.g. "v2/en_speaker_6").

In the TTS UI, the important distinction:

- For cloned voices: show/use the speaker_id.

- For preset voices: no upload/record controls; just a dropdown like:

 ▫ SpeechT5 – Default

 ▫ Bark – EN Speaker 0

 ▫ Bark – EN Speaker 6 (emotional)

4. Where each specific model appears in the UI

To make it crystal clear:

- XTTS v2

 ▫ Models page: Voice Cloning.

 ▫ Voice Cloning: clone from WAV → speaker IDs.

 ▫ TTS: use those speaker IDs for multilingual TTS.

- OpenVoice

 ▫ Same as XTTS: clone in Voice Cloning, use in TTS.

- VALL‑E X

 ▫ Same: clone in Voice Cloning, use cloned speakers in TTS.

- SpeechT5

 ▫ Models page: Text to Speech.

 ▫ TTS section: selectable as “SpeechT5 default voice,” no WAV required.

 ▫ Not in Voice Cloning (until you decide to implement xvector extraction yourself).

- Bark

 ▫ Models page: Text to Speech.

 ▫ TTS section: list all Bark presets; no cloning step.

- Whisper + SeamlessM4T

 ▫ Models page: Speech to Text / Multilingual.

 ▫ Recording and any transcription features.

5. One backend tweak to apply

From the Python we looked at, one change is important for natural output:

In /synthesize, stop stripping punctuation:# Current (too aggressive)

text = data['text'].strip()

text = text.replace('.', ' ').replace(',', ' ').replace(':', ' ').replace(';', ' ')

text = ' '.join(text.split())

Replace with:text = ' '.join(data['text'].strip().split())

This keeps sentence boundaries, which XTTS/OpenVoice/VALL‑E X really need for natural prosody in English/Italian/other languages.

If you shape the sidebar as:

- Models

- Recording

- Voice Cloning

- TTS

- Processing

- History

and wire the models exactly as above, EchoCore Pro will feel logically consistent: Models = inventory, Recording = raw audio, Voice Cloning = who is speaking, TTS = what they say and with which engine, Processing/History = what you do with the finished sound.

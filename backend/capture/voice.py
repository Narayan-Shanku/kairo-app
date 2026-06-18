"""Voice capture — on-device transcription with faster-whisper.

The browser records audio (typically WebM/Opus). We decode it to 16 kHz mono
WAV with ffmpeg (robust across container formats) and transcribe locally. The
Whisper model is loaded once and reused.
"""

from __future__ import annotations

import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from backend import config

_model = None  # lazily-initialised faster_whisper.WhisperModel singleton


@dataclass
class TranscriptResult:
    text: str
    language: str
    duration_seconds: float


def _get_model():
    global _model
    if _model is None:
        from faster_whisper import WhisperModel

        # CPU + int8 is fast and light on Apple Silicon; downloads on first use.
        _model = WhisperModel(
            config.WHISPER_MODEL,
            device="cpu",
            compute_type=config.WHISPER_COMPUTE,
        )
    return _model


def _to_wav(src: Path) -> Path:
    """Convert any audio container to 16 kHz mono WAV via ffmpeg."""
    if shutil.which("ffmpeg") is None:
        # faster-whisper can decode many formats directly via PyAV; fall back.
        return src
    out = Path(tempfile.mkstemp(suffix=".wav")[1])
    subprocess.run(
        ["ffmpeg", "-y", "-i", str(src), "-ar", "16000", "-ac", "1", str(out)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return out


def transcribe(audio_path: str | Path) -> TranscriptResult:
    """Transcribe an audio file to text using faster-whisper (on-device)."""
    src = Path(audio_path)
    wav: Optional[Path] = None
    try:
        wav = _to_wav(src)
        model = _get_model()
        segments, info = model.transcribe(str(wav), beam_size=5, vad_filter=True)
        text = " ".join(seg.text.strip() for seg in segments).strip()
        return TranscriptResult(
            text=text,
            language=getattr(info, "language", "en") or "en",
            duration_seconds=float(getattr(info, "duration", 0.0) or 0.0),
        )
    finally:
        if wav is not None and wav != src and wav.exists():
            wav.unlink(missing_ok=True)

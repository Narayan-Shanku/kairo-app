"""Raw file storage (Technical Architecture §3.3.3).

Persists original audio recordings under ``~/.kairo/audio`` so a memory can be
traced back to its source. Returns the stored path for use as a chunk's raw_ref.
"""

from __future__ import annotations

import shutil
from pathlib import Path

from backend import config


def save_audio(src_path: str | Path, session_id: str, suffix: str = ".webm") -> str:
    """Copy an uploaded audio file into the audio store; return its path."""
    dest = config.AUDIO_DIR / f"{session_id}{suffix}"
    shutil.copyfile(src_path, dest)
    return str(dest)

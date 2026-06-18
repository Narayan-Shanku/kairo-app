"""Text capture — normalizes free-form text input.

The capture layer's only job is to produce clean, timestamped text; chunking,
embedding, and tagging happen downstream in the structure layer.
"""

from __future__ import annotations

import re


def normalize(text: str) -> str:
    """Collapse excess whitespace while preserving paragraph breaks."""
    if not text:
        return ""
    # Normalise newlines, collapse runs of spaces/tabs, trim trailing space.
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()

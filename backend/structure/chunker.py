"""Chunking engine (Technical Architecture §3.2.1).

Splits a transcript into sentence-aware chunks using a sliding window:
  * target up to ~512 tokens per chunk
  * ~64-token overlap between adjacent chunks (preserves boundary context)
  * chunks always end on a sentence boundary, never mid-sentence

Tokens are estimated from character count (≈4 chars/token) to avoid pulling in
a tokenizer dependency. A typical 30-second voice check-in is a single chunk.
"""

from __future__ import annotations

import re

from backend import config

_SENTENCE_RE = re.compile(r"[^.!?]+[.!?]?(?:\s+|$)")


def _est_tokens(text: str) -> int:
    return max(1, len(text) // config.CHARS_PER_TOKEN)


def _sentences(text: str) -> list[str]:
    parts = [s.strip() for s in _SENTENCE_RE.findall(text) if s.strip()]
    return parts or ([text.strip()] if text.strip() else [])


def chunk(text: str) -> list[str]:
    """Return a list of sentence-aware chunks for the given text."""
    text = (text or "").strip()
    if not text:
        return []

    sentences = _sentences(text)
    max_tok = config.CHUNK_MAX_TOKENS
    overlap_tok = config.CHUNK_OVERLAP_TOKENS

    chunks: list[str] = []
    current: list[str] = []
    current_tok = 0

    for sent in sentences:
        sent_tok = _est_tokens(sent)
        # If adding this sentence overflows the window, flush the current chunk
        # and seed the next one with a trailing overlap of recent sentences.
        if current and current_tok + sent_tok > max_tok:
            chunks.append(" ".join(current).strip())
            overlap: list[str] = []
            acc = 0
            for prev in reversed(current):
                acc += _est_tokens(prev)
                overlap.insert(0, prev)
                if acc >= overlap_tok:
                    break
            current = overlap
            current_tok = sum(_est_tokens(s) for s in current)

        current.append(sent)
        current_tok += sent_tok

    if current:
        chunks.append(" ".join(current).strip())

    return [c for c in chunks if c]

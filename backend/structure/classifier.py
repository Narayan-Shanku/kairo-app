"""Domain classifier (Technical Architecture §3.2.3).

Assigns each chunk one or more domain labels from the fixed 7-domain taxonomy,
plus an emotional tone and a confidence score. The doc specifies a zero-shot
distilbart-mnli model; to keep v1 dependency-light we use the already-installed
local LLM (Ollama, JSON mode) with keyword pre-tagging as a fast hint and a
robust fallback. The classifier interface is unchanged, so swapping in
distilbart-mnli later is a drop-in.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field

import ollama

from backend import config
from backend.models import ToneType

_client: ollama.Client | None = None


@dataclass
class Classification:
    domains: list[str] = field(default_factory=list)
    confidence: float = 0.0
    tone: ToneType = ToneType.NEUTRAL


def _get_client() -> ollama.Client:
    global _client
    if _client is None:
        _client = ollama.Client(host=config.OLLAMA_HOST)
    return _client


def _keyword_domains(text: str) -> list[str]:
    low = text.lower()
    hits = []
    for domain, keywords in config.DOMAIN_KEYWORDS.items():
        if any(kw in low for kw in keywords):
            hits.append(domain)
    return hits


_PROMPT = """You label a short personal journal entry.

Choose ALL applicable domains from exactly this list:
{domains}

Also classify the emotional tone as one of: positive, neutral, negative, mixed.

Respond ONLY with JSON of the form:
{{"domains": ["Domain1"], "tone": "neutral", "confidence": 0.0}}

confidence is your certainty (0.0-1.0) in the primary (first) domain.

Entry:
\"\"\"{text}\"\"\""""


def classify(text: str) -> Classification:
    """Classify text into domains + tone. Falls back to keywords on any error."""
    kw = _keyword_domains(text)

    try:
        resp = _get_client().chat(
            model=config.LLM_MODEL,
            messages=[{
                "role": "user",
                "content": _PROMPT.format(
                    domains=", ".join(config.DOMAINS), text=text[:2000]
                ),
            }],
            format="json",
            options={"temperature": 0},
        )
        data = json.loads(resp["message"]["content"])
        domains = [d for d in data.get("domains", []) if d in config.DOMAINS]
        tone_raw = str(data.get("tone", "neutral")).lower()
        tone = ToneType(tone_raw) if tone_raw in ToneType._value2member_map_ else ToneType.NEUTRAL
        confidence = float(data.get("confidence", 0.5))
    except Exception:
        domains, tone, confidence = [], ToneType.NEUTRAL, 0.3

    # Union the LLM result with keyword hits (keyword recall complements the LLM).
    merged = list(dict.fromkeys(domains + kw))
    if not merged:
        merged = ["Learning"]  # safe default bucket for general reflections
        confidence = min(confidence, 0.3)

    return Classification(
        domains=merged,
        confidence=max(0.0, min(1.0, confidence)),
        tone=tone,
    )

"""Day-3 recall (Technical Architecture §4.1).

Proactively resurfaces a notable memory from a few days ago with a warm, generated
follow-up prompt — Kairō's first "wow" mechanic. Computed on demand (no background
scheduler needed for the MVP) and cached per day in user_preferences so it's stable
within a day and never resurfaces the same memory twice.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone

import ollama

from backend import config
from backend.models import new_id  # noqa: F401 (kept for parity)
from backend.retrieval.rag import human_date
from backend.storage import db, vectors

_client: ollama.Client | None = None

# Resurface memories roughly this many days old (the "Day-3" window).
_MIN_AGE_DAYS = 2
_MAX_AGE_DAYS = 5

_PROMPT = """A few days ago someone wrote this in their personal journal:

"{text}"

Write ONE short, warm follow-up question (max 20 words) checking in on it, like a \
thoughtful friend. Start naturally (e.g. "A few days ago you mentioned…"). Output \
only the question."""


def _get_client() -> ollama.Client:
    global _client
    if _client is None:
        _client = ollama.Client(host=config.OLLAMA_HOST)
    return _client


def _surfaced_ids() -> set[str]:
    raw = db.get_pref("recall_surfaced")
    return set(json.loads(raw)) if raw else set()


def _mark_surfaced(memory_id: str) -> None:
    ids = _surfaced_ids()
    ids.add(memory_id)
    db.set_pref("recall_surfaced", json.dumps(list(ids)))


def _candidate():
    """Most 'specific' (longest) unsurfaced memory in the Day-3 age window."""
    now = datetime.now(timezone.utc)
    surfaced = _surfaced_ids()
    pool = []
    for m in vectors.list_memories(limit=500):
        ts = m.timestamp if m.timestamp.tzinfo else m.timestamp.replace(tzinfo=timezone.utc)
        age = (now - ts).days
        if _MIN_AGE_DAYS <= age <= _MAX_AGE_DAYS and m.chunk_id not in surfaced:
            pool.append(m)
    pool.sort(key=lambda m: len(m.text), reverse=True)
    return pool[0] if pool else None


def _generate_prompt(text: str) -> str:
    try:
        resp = _get_client().chat(
            model=config.LLM_MODEL,
            messages=[{"role": "user", "content": _PROMPT.format(text=text[:600])}],
            options={"temperature": 0.4},
        )
        line = resp["message"]["content"].strip().splitlines()[0].strip().strip('"')
        if line:
            return line
    except Exception:
        pass
    return f"A few days ago you noted: “{text[:80]}…”. How did that turn out?"


def todays_recall() -> dict | None:
    """Return today's recall card (cached), or None if there's nothing to surface."""
    today = datetime.now(timezone.utc).date().isoformat()
    key = f"recall:{today}"
    cached = db.get_pref(key)
    if cached:
        card = json.loads(cached)
        # Once the user has responded to / dismissed it, don't resurface today.
        if db.get_pref(f"recall_response:{card['memory_id']}"):
            return None
        return card

    memory = _candidate()
    if memory is None:
        return None

    card = {
        "memory_id": memory.chunk_id,
        "prompt": _generate_prompt(memory.text),
        "date": human_date(memory.timestamp),
        "snippet": memory.text[:200],
        "domain": memory.domains[0] if memory.domains else "General",
    }
    db.set_pref(key, json.dumps(card))
    _mark_surfaced(memory.chunk_id)
    return card


def respond(memory_id: str, response: str) -> dict:
    """User's reply to a recall becomes a new memory (the reflection loop)."""
    text = (response or "").strip()
    if not text:
        return {"saved": False}
    from backend import pipeline  # lazy to avoid an import cycle
    from backend.models import SourceType

    pipeline.ingest_text(text, source=SourceType.INTEGRATION)
    db.set_pref(f"recall_response:{memory_id}", text)
    return {"saved": True}


def dismiss(memory_id: str) -> dict:
    db.set_pref(f"recall_response:{memory_id}", "__dismissed__")
    return {"dismissed": True}

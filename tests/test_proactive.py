"""Proactive Engine tests.

Streak / nudges / recall-candidate selection are pure (seed memories with dummy
vectors — no embeddings needed). Digest generation uses the LLM, so it skips when
Ollama isn't reachable.
"""

from datetime import datetime, timedelta, timezone

import pytest

from backend import config
from backend.models import EnrichedChunk, SourceType, ToneType, new_id
from backend.proactive import nudges, recall, streaks
from backend.storage import db, vectors


def _add_memory(text: str, domains: list[str], days_ago: int) -> str:
    """Insert a memory + session dated `days_ago` (dummy vector, no Ollama)."""
    db.init_db()
    ts = datetime.now(timezone.utc) - timedelta(days=days_ago)
    sid = new_id()
    chunk = EnrichedChunk(
        text=text, timestamp=ts, source_type=SourceType.TEXT,
        session_id=sid, chunk_index=0, vector=[0.0] * config.EMBED_DIM,
        model_name="test", domains=domains, confidence=0.9,
        emotional_tone=ToneType.NEUTRAL, word_count=len(text.split()),
    )
    vectors.add_chunks([chunk])
    db.record_session(session_id=sid, source_type="text",
                      word_count=chunk.word_count, chunk_count=1, timestamp=ts)
    return chunk.chunk_id


# --------------------------------------------------------------------------- #
# Streaks
# --------------------------------------------------------------------------- #
def test_streak_counts_consecutive_days():
    _add_memory("today entry", ["Career"], 0)
    _add_memory("yesterday entry", ["Career"], 1)
    _add_memory("two days ago", ["Career"], 2)
    info = streaks.streak_info()
    assert info["checked_in_today"] is True
    assert info["current"] >= 3


# --------------------------------------------------------------------------- #
# Nudges
# --------------------------------------------------------------------------- #
def test_pattern_nudge_for_busy_domain():
    for i in range(3):
        _add_memory(f"health note {i}", ["Health"], i + 1)
    msgs = " ".join(n["message"] for n in nudges.current_nudges())
    assert "Health" in msgs


# --------------------------------------------------------------------------- #
# Day-3 recall candidate selection (no LLM)
# --------------------------------------------------------------------------- #
def test_recall_candidate_in_age_window():
    cid = _add_memory(
        "A longer, specific memory from a few days ago about a decision I made",
        ["Projects"], 3)
    candidate = recall._candidate()
    assert candidate is not None
    # The freshly added 3-day-old memory is a valid candidate.
    ids = {m.chunk_id for m in vectors.list_memories(limit=500)}
    assert cid in ids


# --------------------------------------------------------------------------- #
# Weekly digest (requires Ollama)
# --------------------------------------------------------------------------- #
def _ollama_ready() -> bool:
    try:
        import ollama
        names = {m.model for m in ollama.Client(host=config.OLLAMA_HOST).list().models}
        return any(config.LLM_MODEL in n for n in names)
    except Exception:
        return False


@pytest.mark.skipif(not _ollama_ready(), reason="Ollama not available")
def test_digest_generates_text():
    from backend.proactive import digest
    _add_memory("Cracked a tricky bug in the analytics pipeline today", ["Projects"], 1)
    result = digest.generate(force=True)
    assert result["memory_count"] >= 1
    assert len(result["digest_text"]) > 20

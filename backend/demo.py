"""Demo data seeding.

Populates a believable, multi-domain memory store so a first-time visitor sees
Kairō's value immediately instead of an empty app. Domains/tone are pre-assigned
(no per-chunk LLM call) so seeding is fast — only embeddings are computed — and
timestamps are backdated so the timeline, insights, and recency ranking look real.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from backend import config
from backend.models import EnrichedChunk, SourceType, ToneType, new_id
from backend.storage import db, vectors
from backend.structure import embedder

# (text, [domains], tone, days_ago, source)
_SEED: list[tuple[str, list[str], ToneType, int, SourceType]] = [
    ("Had a rough stomach today, felt bloated after lunch. Had dal and rice again. "
     "Didn't sleep well last night either — up past 1am working on the project.",
     ["Health"], ToneType.NEGATIVE, 2, SourceType.VOICE),
    ("Bloated again this evening after heavy lentils for dinner, and only got five "
     "hours of sleep.", ["Health"], ToneType.NEGATIVE, 9, SourceType.TEXT),
    ("Slept a full eight hours and skipped the lentils — felt light and clear all "
     "day. Starting to notice a pattern here.", ["Health"], ToneType.POSITIVE, 5,
     SourceType.VOICE),
    ("Skipped breakfast before back-to-back meetings and crashed hard around 3pm. "
     "Need to stop doing that on meeting-heavy days.",
     ["Health", "Career"], ToneType.NEGATIVE, 15, SourceType.VOICE),
    ("Realized I should frame my resume around impact metrics, not responsibilities. "
     "Reworded the analytics project bullet to lead with the result.",
     ["Career"], ToneType.POSITIVE, 20, SourceType.TEXT),
    ("Manager 1:1 went really smoothly when I led with a short written agenda. "
     "Keeping that habit for every check-in.", ["Career"], ToneType.POSITIVE, 12,
     SourceType.VOICE),
    ("Finally cracked SQL window functions in the lab today — PARTITION BY was the "
     "piece I kept missing.", ["Learning"], ToneType.POSITIVE, 8, SourceType.TEXT),
    ("Re-read my notes on RAG re-ranking. Reciprocal Rank Fusion finally clicked — "
     "it's just summing reciprocal ranks across result lists.",
     ["Learning", "Projects"], ToneType.POSITIVE, 3, SourceType.TEXT),
    ("Fixed the ChromaDB persistence bug — it needed the PersistentClient path set "
     "explicitly instead of the in-memory default.",
     ["Projects"], ToneType.POSITIVE, 6, SourceType.VOICE),
    ("Shipped the voice capture flow end to end — Whisper to Chroma to Ollama all "
     "working. Felt great to see the first grounded answer come back.",
     ["Projects"], ToneType.POSITIVE, 1, SourceType.VOICE),
    ("Morning walk before work again — my afternoon focus is noticeably better on "
     "the days I walk.", ["Fitness", "Health"], ToneType.POSITIVE, 4,
     SourceType.VOICE),
    ("Recalculated the monthly budget after the rent increase. Cutting two "
     "subscriptions I never use.", ["Finance"], ToneType.NEUTRAL, 18,
     SourceType.TEXT),
    ("Good call with my mentor about whether to go deeper on product or stay "
     "analytics-focused. Leaning toward product, but sitting with it.",
     ["Relationships", "Career"], ToneType.MIXED, 11, SourceType.VOICE),
]


# (card_type, front, back, domain) — pre-made so the Review tab is populated
# instantly without an LLM call per card.
_SEED_CARDS: list[tuple[str, str, str, str]] = [
    ("insight", "What's your strongest bloating trigger?",
     "Dal / heavy lentils within a few hours — especially on nights you slept "
     "under 6 hours.", "Health"),
    ("insight", "What reliably improves your afternoon focus?",
     "A morning walk before work — you're noticeably sharper on walk days.",
     "Fitness"),
    ("decision", "You decided to lead every manager 1:1 with a written agenda. "
     "Did it hold up?",
     "Decision: lead 1:1s with a short written agenda (it made them go smoothly).",
     "Career"),
    ("insight", "What was the missing piece for SQL window functions?",
     "PARTITION BY — that's what made window functions finally click.", "Learning"),
    ("decision", "You planned to cut two unused subscriptions after the rent "
     "increase. Did you follow through?",
     "Decision: trim two unused subscriptions to rebalance the monthly budget.",
     "Finance"),
]


def is_seeded() -> bool:
    return db.get_pref("demo_seeded") == "1"


def seed() -> dict:
    """Insert demo memories if not already present. Returns a small summary."""
    if is_seeded():
        return {"seeded": False, "already": True, "count": vectors.count()}

    now = datetime.now(timezone.utc)
    texts = [s[0] for s in _SEED]
    vecs = embedder.embed_documents(texts)

    added = 0
    for (text, domains, tone, days_ago, source), vec in zip(_SEED, vecs):
        session_id = new_id()
        ts = now - timedelta(days=days_ago, hours=3)
        chunk = EnrichedChunk(
            text=text,
            timestamp=ts,
            source_type=source,
            session_id=session_id,
            chunk_index=0,
            vector=vec,
            model_name=config.EMBED_MODEL,
            domains=domains,
            confidence=0.92,
            emotional_tone=tone,
            word_count=len(text.split()),
        )
        vectors.add_chunks([chunk])
        db.record_session(
            session_id=session_id,
            source_type=source.value,
            word_count=chunk.word_count,
            chunk_count=1,
            preview=text[:200],
            timestamp=ts,
        )
        added += 1

    # Seed pre-made review cards (due now) so the Review tab isn't empty.
    card_ts = (now - timedelta(days=1)).isoformat()
    for ctype, front, back, domain in _SEED_CARDS:
        db.insert_card({
            "card_id": new_id(),
            "card_type": ctype,
            "front": front,
            "back": back,
            "domain": domain,
            "created_at": card_ts,
            "due_date": card_ts,
        })

    db.set_pref("demo_seeded", "1")
    return {"seeded": True, "already": False, "count": added, "cards": len(_SEED_CARDS)}

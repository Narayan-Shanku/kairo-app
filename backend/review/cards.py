"""Review card lifecycle — generation, pinning, due queue, review, stats.

Cards are distilled from the user's own memories (LLM, quality-gated) or pinned
manually. Reviewing a *decision* card with a reflection writes a new memory back
into the store — the validation loop that makes review compound the memory graph.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone

import ollama

from backend import config
from backend.models import new_id
from backend.review import scheduler
from backend.review.scheduler import CardState
from backend.storage import db, vectors

_client: ollama.Client | None = None

_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _human_date(ts: datetime) -> str:
    return f"{_MONTHS[ts.month - 1]} {ts.day}, {ts.year}"


def _get_client() -> ollama.Client:
    global _client
    if _client is None:
        _client = ollama.Client(host=config.OLLAMA_HOST)
    return _client


# --------------------------------------------------------------------------- #
# Generation
# --------------------------------------------------------------------------- #
_GEN_PROMPT = """You decide whether a personal journal entry contains something \
worth REMEMBERING long-term as a spaced-repetition flashcard.

Return ONLY JSON:
{{"type": "insight" | "decision" | "none", "front": "...", "back": "...", "confidence": 0.0}}

- "insight": the entry holds a durable, reusable lesson or finding the person \
would benefit from recalling later (a health trigger, a method that worked, a \
principle). front = a short question testing recall of the lesson. back = the \
lesson, concisely, in the person's own framing.
- "decision": the person made a decision, plan, intention, or resolution worth \
following up on. front = a question asking whether that decision held up or \
worked. back = a one-line restatement of the decision for context.
- "none": a routine log with no reusable takeaway. Be conservative — prefer \
"none" unless there is a clear lesson or a concrete decision.

Entry:
\"\"\"{text}\"\"\""""


def generate_from_memory(
    text: str, chunk_ids: list[str], domains: list[str]
) -> dict | None:
    """LLM-distill a card from a memory. Returns the card dict, or None if the
    entry has no durable, reusable takeaway (the quality gate)."""
    try:
        resp = _get_client().chat(
            model=config.LLM_MODEL,
            messages=[{"role": "user", "content": _GEN_PROMPT.format(text=text[:2000])}],
            format="json",
            options={"temperature": 0},
        )
        data = json.loads(resp["message"]["content"])
    except Exception:
        return None

    ctype = str(data.get("type", "none")).lower()
    front = (data.get("front") or "").strip()
    back = (data.get("back") or "").strip()
    confidence = float(data.get("confidence", 0.0) or 0.0)

    if ctype not in ("insight", "decision") or not front or not back or confidence < 0.6:
        return None

    return _create_card(
        card_type=ctype,
        front=front,
        back=back,
        source_chunk_ids=chunk_ids,
        domain=domains[0] if domains else "",
    )


# --------------------------------------------------------------------------- #
# Card creation / pinning
# --------------------------------------------------------------------------- #
def _create_card(
    *, card_type: str, front: str, back: str,
    source_chunk_ids: list[str] | None = None, domain: str = "",
    due_at: datetime | None = None,
) -> dict:
    now = _now()
    card = {
        "card_id": new_id(),
        "card_type": card_type,
        "front": front,
        "back": back,
        "source_chunk_ids": ",".join(source_chunk_ids or []),
        "domain": domain,
        "created_at": now.isoformat(),
        "due_date": (due_at or now).isoformat(),  # new cards are due immediately
    }
    db.insert_card(card)
    return card


def pin_memory(chunk_id: str) -> dict | None:
    """Pin an existing memory as a recall card."""
    mem = vectors.get_by_id(chunk_id)
    if not mem:
        return None
    domain = mem.domains[0] if mem.domains else "General"
    return _create_card(
        card_type="pinned",
        front=f"Recall your note from {_human_date(mem.timestamp)} ({domain})",
        back=mem.text,
        source_chunk_ids=[chunk_id],
        domain=domain,
    )


def pin_qa(front: str, back: str, domain: str = "") -> dict:
    """Pin an Ask answer (question → answer) as a card."""
    return _create_card(card_type="pinned", front=front, back=back, domain=domain)


# --------------------------------------------------------------------------- #
# Due queue / review
# --------------------------------------------------------------------------- #
def _public(card: dict) -> dict:
    return {
        "card_id": card["card_id"],
        "type": card["card_type"],
        "front": card["front"],
        "back": card["back"],
        "domain": card["domain"],
        "due_date": card["due_date"],
    }


def due(limit: int = 20) -> list[dict]:
    return [_public(c) for c in db.due_cards(_now().isoformat(), limit)]


def review(card_id: str, rating: str, reflection: str | None = None) -> dict:
    """Record a review: reschedule via SM-2, and for decision cards optionally
    write the reflection back as a new memory (the validation loop)."""
    card = db.get_card(card_id)
    if not card:
        raise ValueError("card not found")

    state = CardState(
        ease=card["ease"],
        interval_days=card["interval_days"],
        repetitions=card["repetitions"],
        lapses=card["lapses"],
    )
    new_state = scheduler.schedule(state, rating)

    now = _now()
    due_date = now + timedelta(days=new_state.interval_days)
    db.update_card_schedule(
        card_id,
        ease=new_state.ease,
        interval_days=new_state.interval_days,
        repetitions=new_state.repetitions,
        lapses=new_state.lapses,
        due_date=due_date.isoformat(),
        last_reviewed=now.isoformat(),
    )
    db.record_card_review(
        card_id, now.isoformat(), rating,
        card["interval_days"], new_state.interval_days,
    )

    created_memory = False
    if card["card_type"] == "decision" and reflection and reflection.strip():
        from backend import pipeline  # lazy to avoid an import cycle
        from backend.models import SourceType

        pipeline.ingest_text(reflection.strip(), source=SourceType.INTEGRATION)
        created_memory = True

    return {
        "card_id": card_id,
        "rating": rating,
        "interval_days": new_state.interval_days,
        "next_review": _human_date(due_date),
        "created_memory": created_memory,
    }


# --------------------------------------------------------------------------- #
# Stats
# --------------------------------------------------------------------------- #
def _streak(dates: list[str]) -> int:
    """Consecutive-day review streak ending today or yesterday."""
    if not dates:
        return 0
    have = set(dates)
    today = _now().date()
    # Allow the streak to count if the user reviewed today or yesterday.
    cursor = today if today.isoformat() in have else today - timedelta(days=1)
    if cursor.isoformat() not in have:
        return 0
    streak = 0
    while cursor.isoformat() in have:
        streak += 1
        cursor -= timedelta(days=1)
    return streak


def stats() -> dict:
    now = _now()
    dates = db.review_dates()
    return {
        "due": db.due_card_count(now.isoformat()),
        "total": db.card_count(only_active=True),
        "reviewed_today": now.date().isoformat() in set(dates),
        "streak": _streak(dates),
    }

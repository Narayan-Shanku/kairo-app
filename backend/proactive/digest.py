"""Weekly digest (Technical Architecture §4.2).

Generates a reflective summary of the past 7 days — grouped by life domain, with
recurring themes, cross-domain patterns, and open questions — using the local LLM.
Generated on demand and cached per week in the digests table.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import ollama

from backend import config
from backend.storage import db, vectors

_client: ollama.Client | None = None

_PROMPT = """You are Kairō, a personal memory assistant writing someone's weekly \
reflection digest. Below are their memories from the past week, grouped by life \
domain.

Write a warm, concise digest with these sections (use plain text, short paragraphs):
- A one-line opening reflection on the week.
- For each domain present: 1–2 sentences on what happened and any pattern.
- "Cross-domain patterns:" one notable connection across domains, if any.
- "Open questions:" 1–2 unresolved things worth following up on.

Ground everything ONLY in the memories below. Be specific, not generic.

MEMORIES BY DOMAIN:
{context}"""


def _get_client() -> ollama.Client:
    global _client
    if _client is None:
        _client = ollama.Client(host=config.OLLAMA_HOST)
    return _client


def _last_week_memories():
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(days=7)
    out = []
    for m in vectors.list_memories(limit=500):
        ts = m.timestamp if m.timestamp.tzinfo else m.timestamp.replace(tzinfo=timezone.utc)
        if ts >= cutoff:
            out.append(m)
    return out


def _build_context(memories) -> tuple[str, list[str]]:
    by_domain: dict[str, list[str]] = {}
    for m in memories:
        domain = m.domains[0] if m.domains else "General"
        by_domain.setdefault(domain, []).append(m.text)
    lines = []
    for domain, texts in by_domain.items():
        lines.append(f"\n[{domain}]")
        lines.extend(f"- {t}" for t in texts)
    return "\n".join(lines), list(by_domain.keys())


def generate(force: bool = False) -> dict:
    now = datetime.now(timezone.utc).date()
    week_start = (now - timedelta(days=6)).isoformat()
    week_end = now.isoformat()

    if not force:
        existing = db.get_digest(week_start)
        if existing:
            return existing

    memories = _last_week_memories()
    if not memories:
        return {
            "week_start": week_start, "week_end": week_end,
            "digest_text": "No memories captured this week yet — check in to build your digest.",
            "domains_covered": "", "memory_count": 0,
        }

    context, domains = _build_context(memories)
    try:
        resp = _get_client().chat(
            model=config.LLM_MODEL,
            messages=[{"role": "user", "content": _PROMPT.format(context=context[:6000])}],
            options={"temperature": 0.3},
        )
        text = resp["message"]["content"].strip()
    except Exception as e:
        text = f"Couldn't generate the digest right now ({e})."

    db.save_digest(week_start, week_end, text, ",".join(domains))
    return {
        "week_start": week_start, "week_end": week_end,
        "digest_text": text, "domains_covered": ",".join(domains),
        "memory_count": len(memories),
    }


def latest() -> dict | None:
    return db.latest_digest()

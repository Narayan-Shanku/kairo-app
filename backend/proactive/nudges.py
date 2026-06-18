"""Smart nudges (Technical Architecture §4.3).

Contextual, advisor-style prompts derived cheaply from current state (no LLM, so
the proactive endpoint stays fast): streak risk, and recurring-domain patterns.
"""

from __future__ import annotations

from collections import Counter
from datetime import datetime, timedelta, timezone

from backend.proactive import streaks
from backend.storage import vectors


def current_nudges() -> list[dict]:
    nudges: list[dict] = []

    # Streak-risk nudge.
    s = streaks.streak_info()
    if not s["checked_in_today"] and s["current"] > 0:
        nudges.append({
            "type": "streak",
            "message": f"You haven't checked in today — keep your {s['current']}-day streak alive.",
        })

    # Pattern nudges: domains you've logged a lot in over the last two weeks.
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(days=14)
    counts: Counter[str] = Counter()
    for m in vectors.list_memories(limit=500):
        ts = m.timestamp if m.timestamp.tzinfo else m.timestamp.replace(tzinfo=timezone.utc)
        if ts >= cutoff:
            for d in m.domains:
                counts[d] += 1

    for domain, n in counts.most_common(3):
        if n < 3:
            break
        if domain == "Health":
            msg = f"You've logged {n} Health notes lately — ask Kairō what patterns it sees."
        else:
            msg = f"{n} recent entries in {domain} — worth reviewing for a pattern?"
        nudges.append({"type": "pattern", "domain": domain, "message": msg})

    return nudges[:3]

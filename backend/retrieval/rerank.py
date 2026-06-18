"""Domain-aware re-ranking (Technical Architecture §3.4, step 3).

Re-scores fused search results with three signals:
  * domain match boost  — +0.15 when the query's domain matches a chunk's domain
  * recency decay       — exponential, 90-day half-life (recent memories rank up)
  * source diversity    — penalise repeated chunks from the same check-in session
"""

from __future__ import annotations

from datetime import datetime, timezone

from backend import config
from backend.models import SearchResult


def detect_query_domains(query: str) -> list[str]:
    """Lightweight keyword-based domain detection for the query."""
    low = query.lower()
    return [
        domain
        for domain, keywords in config.DOMAIN_KEYWORDS.items()
        if any(kw in low for kw in keywords)
    ]


def _recency_factor(ts: datetime, now: datetime) -> float:
    age_days = max(0.0, (now - ts).total_seconds() / 86400.0)
    return 0.5 ** (age_days / config.RECENCY_HALFLIFE_DAYS)


def rerank(results: list[SearchResult], query: str) -> list[SearchResult]:
    """Apply domain/recency/diversity adjustments and return a new ranking."""
    if not results:
        return []

    query_domains = set(detect_query_domains(query))
    now = datetime.now(timezone.utc)

    # Normalise fused (RRF) scores to [0,1] so the additive boosts are comparable.
    max_score = max((r.score for r in results), default=0.0) or 1.0

    session_seen: dict[str, int] = {}
    rescored: list[SearchResult] = []
    for r in results:
        base = r.score / max_score

        domain_boost = config.DOMAIN_BOOST if query_domains & set(r.domains) else 0.0

        ts = r.timestamp
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        recency = config.DOMAIN_BOOST * _recency_factor(ts, now)

        seen = session_seen.get(r.session_id, 0)
        diversity_penalty = config.SESSION_DIVERSITY_PENALTY * seen
        session_seen[r.session_id] = seen + 1

        r.score = base + domain_boost + recency - diversity_penalty
        rescored.append(r)

    rescored.sort(key=lambda x: x.score, reverse=True)
    return rescored

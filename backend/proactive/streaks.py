"""Check-in streak (Duolingo-style retention mechanic).

Computed on-demand from the distinct dates in the sessions table — no separate
counter to keep in sync, and it works with any data (including the demo set).
"""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from backend.storage import db


def _dates() -> set[date]:
    out: set[date] = set()
    for d in db.checkin_dates():
        try:
            out.add(date.fromisoformat(d))
        except ValueError:
            pass
    return out


def streak_info() -> dict:
    dates = _dates()
    today = datetime.now(timezone.utc).date()
    checked_in_today = today in dates

    # Current streak: consecutive days ending today (or yesterday if not yet today).
    cursor = today if checked_in_today else today - timedelta(days=1)
    current = 0
    while cursor in dates:
        current += 1
        cursor -= timedelta(days=1)

    # Longest streak across all history.
    longest = 0
    run = 0
    prev: date | None = None
    for d in sorted(dates):
        run = run + 1 if (prev is not None and d == prev + timedelta(days=1)) else 1
        longest = max(longest, run)
        prev = d

    return {
        "current": current,
        "longest": longest,
        "checked_in_today": checked_in_today,
        "total_days": len(dates),
    }

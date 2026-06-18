"""SM-2 spaced-repetition scheduler (Anki's classic algorithm).

Pure and dependency-free so it's trivially unit-testable. Given a card's current
state and the user's recall rating, it returns the next state (ease, interval,
repetitions, lapses). The caller turns ``interval_days`` into a due date.

Ratings (UI) map to SM-2 quality ``q`` (0–5 scale; q < 3 is a lapse):
    Again → 2   Hard → 3   Good → 4   Easy → 5
"""

from __future__ import annotations

from dataclasses import dataclass

# UI rating -> SM-2 quality
AGAIN, HARD, GOOD, EASY = "again", "hard", "good", "easy"
_QUALITY = {AGAIN: 2, HARD: 3, GOOD: 4, EASY: 5}
RATINGS = (AGAIN, HARD, GOOD, EASY)

DEFAULT_EASE = 2.5
MIN_EASE = 1.3


@dataclass
class CardState:
    ease: float = DEFAULT_EASE
    interval_days: float = 0.0
    repetitions: int = 0
    lapses: int = 0


def schedule(state: CardState, rating: str) -> CardState:
    """Return the next CardState for the given recall rating."""
    if rating not in _QUALITY:
        raise ValueError(f"unknown rating: {rating!r}")
    q = _QUALITY[rating]

    # Update ease factor (SM-2 formula), clamped to a sane floor.
    ease = state.ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    ease = max(MIN_EASE, ease)

    if q < 3:  # lapse — restart the card
        return CardState(
            ease=ease,
            interval_days=1.0,
            repetitions=0,
            lapses=state.lapses + 1,
        )

    reps = state.repetitions
    if reps == 0:
        interval = 1.0
    elif reps == 1:
        interval = 6.0
    else:
        interval = round(state.interval_days * ease)

    return CardState(
        ease=ease,
        interval_days=float(interval),
        repetitions=reps + 1,
        lapses=state.lapses,
    )

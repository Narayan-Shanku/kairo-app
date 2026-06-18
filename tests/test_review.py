"""Review layer tests.

SM-2 scheduling and card CRUD/review are pure (no models needed). The validation
loop touches the embedding pipeline, so it skips when Ollama isn't reachable.
"""

import datetime

import pytest

from backend import config
from backend.review import scheduler
from backend.review.scheduler import CardState


# --------------------------------------------------------------------------- #
# SM-2 scheduler (pure)
# --------------------------------------------------------------------------- #
def test_sm2_good_progression():
    st = CardState()
    st = scheduler.schedule(st, "good")
    assert st.interval_days == 1 and st.repetitions == 1
    st = scheduler.schedule(st, "good")
    assert st.interval_days == 6 and st.repetitions == 2
    st = scheduler.schedule(st, "good")
    assert st.interval_days == 15 and st.repetitions == 3  # 6 * 2.5


def test_sm2_again_resets_and_lapses():
    st = CardState(ease=2.5, interval_days=15, repetitions=4, lapses=0)
    st = scheduler.schedule(st, "again")
    assert st.interval_days == 1
    assert st.repetitions == 0
    assert st.lapses == 1


def test_sm2_ease_has_floor():
    st = CardState()
    for _ in range(12):
        st = scheduler.schedule(st, "again")
    assert st.ease >= scheduler.MIN_EASE


def test_sm2_easy_raises_ease():
    assert scheduler.schedule(CardState(), "easy").ease > CardState().ease


def test_sm2_rejects_unknown_rating():
    with pytest.raises(ValueError):
        scheduler.schedule(CardState(), "perfect")


# --------------------------------------------------------------------------- #
# Card lifecycle (no Ollama needed)
# --------------------------------------------------------------------------- #
@pytest.fixture
def db_ready():
    from backend.storage import db

    db.init_db()
    return db


def _past_iso(days=1):
    return (
        datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=days)
    ).isoformat()


def test_card_due_and_review(db_ready):
    from backend.review import cards

    db_ready.insert_card({
        "card_id": "t-due", "card_type": "insight",
        "front": "Q?", "back": "A.", "created_at": _past_iso(), "due_date": _past_iso(),
    })
    assert any(c["card_id"] == "t-due" for c in cards.due(limit=20))

    res = cards.review("t-due", "good")
    assert res["interval_days"] == 1
    assert res["created_memory"] is False
    # Rescheduled into the future -> no longer due.
    assert all(c["card_id"] != "t-due" for c in cards.due(limit=20))


def test_review_missing_card_raises(db_ready):
    from backend.review import cards

    with pytest.raises(ValueError):
        cards.review("does-not-exist", "good")


# --------------------------------------------------------------------------- #
# Validation loop (requires Ollama for embedding the new memory)
# --------------------------------------------------------------------------- #
def _ollama_ready() -> bool:
    try:
        import ollama

        names = {m.model for m in ollama.Client(host=config.OLLAMA_HOST).list().models}
        return any(config.EMBED_MODEL in n for n in names)
    except Exception:
        return False


@pytest.mark.skipif(not _ollama_ready(), reason="Ollama not available")
def test_decision_card_reflection_creates_memory(db_ready):
    from backend.review import cards
    from backend.storage import vectors

    db_ready.insert_card({
        "card_id": "t-dec", "card_type": "decision",
        "front": "Did the agenda habit hold up?",
        "back": "Decision: lead 1:1s with a written agenda.",
        "created_at": _past_iso(), "due_date": _past_iso(),
    })
    before = vectors.count()
    res = cards.review(
        "t-dec", "good",
        reflection="Yes — the written agenda stuck and 1:1s are much smoother now.",
    )
    assert res["created_memory"] is True
    assert vectors.count() == before + 1

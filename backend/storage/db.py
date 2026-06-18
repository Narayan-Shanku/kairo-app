"""SQLite metadata store (Technical Architecture §3.3.2).

Holds structured app state separate from the vector store. Milestone 1 actively
uses ``sessions`` and ``user_preferences``; the ``streaks``, ``digests``, and
``proactive_queue`` tables are created now (full schema) so the Proactive Engine
in Milestone 2 is a pure additive change.
"""

from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Iterator

from backend import config

_SCHEMA = """
CREATE TABLE IF NOT EXISTS sessions (
    session_id      TEXT PRIMARY KEY,
    timestamp       TEXT NOT NULL,
    duration_seconds REAL DEFAULT 0,
    source_type     TEXT NOT NULL,
    word_count      INTEGER DEFAULT 0,
    chunk_count     INTEGER DEFAULT 0,
    preview         TEXT DEFAULT ''
);

CREATE TABLE IF NOT EXISTS user_preferences (
    key   TEXT PRIMARY KEY,
    value TEXT
);

-- Reserved for Milestone 2 (Proactive Engine):
CREATE TABLE IF NOT EXISTS streaks (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    current_streak  INTEGER DEFAULT 0,
    longest_streak  INTEGER DEFAULT 0,
    last_checkin_date TEXT,
    freeze_available INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS digests (
    week_start TEXT PRIMARY KEY,
    week_end   TEXT,
    digest_text TEXT,
    domains_covered TEXT
);

CREATE TABLE IF NOT EXISTS proactive_queue (
    memory_id    TEXT PRIMARY KEY,
    surface_date TEXT,
    surfaced     INTEGER DEFAULT 0,
    user_response TEXT
);

-- Spaced-repetition review cards (SM-2 scheduling):
CREATE TABLE IF NOT EXISTS cards (
    card_id          TEXT PRIMARY KEY,
    card_type        TEXT NOT NULL,        -- insight | decision | pinned
    front            TEXT NOT NULL,
    back             TEXT NOT NULL,
    source_chunk_ids TEXT DEFAULT '',      -- csv of originating chunk ids
    domain           TEXT DEFAULT '',
    created_at       TEXT NOT NULL,
    status           TEXT DEFAULT 'active', -- active | suspended
    ease             REAL DEFAULT 2.5,
    interval_days    REAL DEFAULT 0,
    repetitions      INTEGER DEFAULT 0,
    lapses           INTEGER DEFAULT 0,
    due_date         TEXT NOT NULL,
    last_reviewed    TEXT
);
CREATE INDEX IF NOT EXISTS idx_cards_due ON cards(status, due_date);

CREATE TABLE IF NOT EXISTS card_reviews (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    card_id       TEXT NOT NULL,
    reviewed_at   TEXT NOT NULL,
    rating        TEXT NOT NULL,
    prev_interval REAL,
    new_interval  REAL
);
"""


@contextmanager
def connect() -> Iterator[sqlite3.Connection]:
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db() -> None:
    with connect() as conn:
        conn.executescript(_SCHEMA)


def record_session(
    *,
    session_id: str,
    source_type: str,
    word_count: int,
    chunk_count: int,
    duration_seconds: float = 0.0,
    preview: str = "",
    timestamp: datetime | None = None,
) -> None:
    ts = (timestamp or datetime.now(timezone.utc)).isoformat()
    with connect() as conn:
        conn.execute(
            """INSERT OR REPLACE INTO sessions
               (session_id, timestamp, duration_seconds, source_type,
                word_count, chunk_count, preview)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (session_id, ts, duration_seconds, source_type,
             word_count, chunk_count, preview[:280]),
        )


def set_pref(key: str, value: str) -> None:
    with connect() as conn:
        conn.execute(
            "INSERT OR REPLACE INTO user_preferences (key, value) VALUES (?, ?)",
            (key, value),
        )


def get_pref(key: str, default: str | None = None) -> str | None:
    with connect() as conn:
        row = conn.execute(
            "SELECT value FROM user_preferences WHERE key = ?", (key,)
        ).fetchone()
    return row["value"] if row else default


def recent_sessions(limit: int = 20) -> list[dict]:
    with connect() as conn:
        rows = conn.execute(
            "SELECT * FROM sessions ORDER BY timestamp DESC LIMIT ?", (limit,)
        ).fetchall()
    return [dict(r) for r in rows]


def session_count() -> int:
    with connect() as conn:
        row = conn.execute("SELECT COUNT(*) AS n FROM sessions").fetchone()
    return int(row["n"])


# --------------------------------------------------------------------------- #
# Review cards
# --------------------------------------------------------------------------- #
def insert_card(card: dict) -> None:
    with connect() as conn:
        conn.execute(
            """INSERT OR REPLACE INTO cards
               (card_id, card_type, front, back, source_chunk_ids, domain,
                created_at, status, ease, interval_days, repetitions, lapses,
                due_date, last_reviewed)
               VALUES (:card_id, :card_type, :front, :back, :source_chunk_ids,
                :domain, :created_at, :status, :ease, :interval_days,
                :repetitions, :lapses, :due_date, :last_reviewed)""",
            {
                "status": "active",
                "ease": 2.5,
                "interval_days": 0,
                "repetitions": 0,
                "lapses": 0,
                "last_reviewed": None,
                "source_chunk_ids": "",
                "domain": "",
                **card,
            },
        )


def get_card(card_id: str) -> dict | None:
    with connect() as conn:
        row = conn.execute(
            "SELECT * FROM cards WHERE card_id = ?", (card_id,)
        ).fetchone()
    return dict(row) if row else None


def due_cards(now_iso: str, limit: int = 20) -> list[dict]:
    with connect() as conn:
        rows = conn.execute(
            """SELECT * FROM cards
               WHERE status = 'active' AND due_date <= ?
               ORDER BY due_date ASC LIMIT ?""",
            (now_iso, limit),
        ).fetchall()
    return [dict(r) for r in rows]


def list_cards(limit: int = 200) -> list[dict]:
    with connect() as conn:
        rows = conn.execute(
            "SELECT * FROM cards ORDER BY created_at DESC LIMIT ?", (limit,)
        ).fetchall()
    return [dict(r) for r in rows]


def update_card_schedule(
    card_id: str,
    *,
    ease: float,
    interval_days: float,
    repetitions: int,
    lapses: int,
    due_date: str,
    last_reviewed: str,
) -> None:
    with connect() as conn:
        conn.execute(
            """UPDATE cards SET ease=?, interval_days=?, repetitions=?, lapses=?,
               due_date=?, last_reviewed=? WHERE card_id=?""",
            (ease, interval_days, repetitions, lapses, due_date,
             last_reviewed, card_id),
        )


def record_card_review(
    card_id: str, reviewed_at: str, rating: str,
    prev_interval: float, new_interval: float,
) -> None:
    with connect() as conn:
        conn.execute(
            """INSERT INTO card_reviews
               (card_id, reviewed_at, rating, prev_interval, new_interval)
               VALUES (?, ?, ?, ?, ?)""",
            (card_id, reviewed_at, rating, prev_interval, new_interval),
        )


def card_count(only_active: bool = True) -> int:
    q = "SELECT COUNT(*) AS n FROM cards"
    if only_active:
        q += " WHERE status = 'active'"
    with connect() as conn:
        return int(conn.execute(q).fetchone()["n"])


def due_card_count(now_iso: str) -> int:
    with connect() as conn:
        row = conn.execute(
            "SELECT COUNT(*) AS n FROM cards WHERE status='active' AND due_date <= ?",
            (now_iso,),
        ).fetchone()
    return int(row["n"])


def review_dates() -> list[str]:
    """Distinct calendar dates (YYYY-MM-DD) on which any card was reviewed."""
    with connect() as conn:
        rows = conn.execute(
            "SELECT DISTINCT substr(reviewed_at, 1, 10) AS d FROM card_reviews"
        ).fetchall()
    return [r["d"] for r in rows]


def checkin_dates() -> list[str]:
    """Distinct calendar dates (YYYY-MM-DD) on which the user checked in."""
    with connect() as conn:
        rows = conn.execute(
            "SELECT DISTINCT substr(timestamp, 1, 10) AS d FROM sessions"
        ).fetchall()
    return [r["d"] for r in rows if r["d"]]


# --------------------------------------------------------------------------- #
# Weekly digests
# --------------------------------------------------------------------------- #
def save_digest(week_start: str, week_end: str, digest_text: str,
                domains_covered: str) -> None:
    with connect() as conn:
        conn.execute(
            """INSERT OR REPLACE INTO digests
               (week_start, week_end, digest_text, domains_covered)
               VALUES (?, ?, ?, ?)""",
            (week_start, week_end, digest_text, domains_covered),
        )


def get_digest(week_start: str) -> dict | None:
    with connect() as conn:
        row = conn.execute(
            "SELECT * FROM digests WHERE week_start = ?", (week_start,)
        ).fetchone()
    return dict(row) if row else None


def latest_digest() -> dict | None:
    with connect() as conn:
        row = conn.execute(
            "SELECT * FROM digests ORDER BY week_start DESC LIMIT 1"
        ).fetchone()
    return dict(row) if row else None

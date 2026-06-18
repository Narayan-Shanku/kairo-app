"""Export / import the local Kairō store as a portable snapshot.

The snapshot is the plaintext that gets encrypted before it ever leaves the
device. It captures everything needed to reconstruct the store on a new device:
memory vectors + metadata (ChromaDB) and sessions / cards / digests / prefs (SQLite).
"""

from __future__ import annotations

from backend.storage import db, vectors

SNAPSHOT_VERSION = 1


def export_snapshot() -> dict:
    col = vectors.get_collection()
    if col.count() > 0:
        res = col.get(include=["documents", "metadatas", "embeddings"])
        memories = {
            "ids": list(res["ids"]),
            "documents": list(res["documents"]),
            "metadatas": [dict(m) for m in res["metadatas"]],
            "embeddings": [[float(x) for x in e] for e in res["embeddings"]],
        }
    else:
        memories = {"ids": [], "documents": [], "metadatas": [], "embeddings": []}

    def table(name: str) -> list[dict]:
        with db.connect() as conn:
            return [dict(r) for r in conn.execute(f"SELECT * FROM {name}").fetchall()]

    return {
        "version": SNAPSHOT_VERSION,
        "memories": memories,
        "sessions": table("sessions"),
        "cards": table("cards"),
        "digests": table("digests"),
        "preferences": table("user_preferences"),
    }


def import_snapshot(snap: dict) -> dict:
    """Merge a snapshot into the local store (idempotent — skips existing ids)."""
    db.init_db()
    added_memories = 0

    mem = snap.get("memories", {})
    ids = mem.get("ids", [])
    if ids:
        col = vectors.get_collection()
        existing = set(col.get()["ids"]) if col.count() else set()
        new_idx = [i for i, cid in enumerate(ids) if cid not in existing]
        if new_idx:
            col.add(
                ids=[ids[i] for i in new_idx],
                embeddings=[mem["embeddings"][i] for i in new_idx],
                documents=[mem["documents"][i] for i in new_idx],
                metadatas=[mem["metadatas"][i] for i in new_idx],
            )
            added_memories = len(new_idx)

    with db.connect() as conn:
        for s in snap.get("sessions", []):
            cols = ",".join(s.keys())
            ph = ",".join("?" for _ in s)
            conn.execute(f"INSERT OR REPLACE INTO sessions ({cols}) VALUES ({ph})",
                         tuple(s.values()))
        for c in snap.get("cards", []):
            cols = ",".join(c.keys())
            ph = ",".join("?" for _ in c)
            conn.execute(f"INSERT OR REPLACE INTO cards ({cols}) VALUES ({ph})",
                         tuple(c.values()))
        for d in snap.get("digests", []):
            cols = ",".join(d.keys())
            ph = ",".join("?" for _ in d)
            conn.execute(f"INSERT OR REPLACE INTO digests ({cols}) VALUES ({ph})",
                         tuple(d.values()))
        for p in snap.get("preferences", []):
            conn.execute(
                "INSERT OR REPLACE INTO user_preferences (key, value) VALUES (?, ?)",
                (p["key"], p["value"]),
            )

    return {
        "memories_added": added_memories,
        "sessions": len(snap.get("sessions", [])),
        "cards": len(snap.get("cards", [])),
    }

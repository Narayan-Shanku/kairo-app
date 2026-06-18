"""Encrypted-sync tests: crypto round-trip + snapshot export. No network/Ollama."""

from datetime import datetime, timezone

import pytest

from backend import config
from backend.models import EnrichedChunk, SourceType, ToneType, new_id
from backend.storage import db, vectors
from backend.sync import crypto, snapshot


# --------------------------------------------------------------------------- #
# Crypto
# --------------------------------------------------------------------------- #
def test_encrypt_decrypt_roundtrip():
    blob = crypto.encrypt(b"a private memory", "correct horse battery staple")
    assert crypto.decrypt(blob, "correct horse battery staple") == b"a private memory"


def test_wrong_passphrase_fails():
    blob = crypto.encrypt(b"secret", "right-passphrase")
    with pytest.raises(Exception):
        crypto.decrypt(blob, "wrong-passphrase")


def test_blob_is_opaque_ciphertext():
    blob = crypto.encrypt(b"my private journal entry about health", "pw")
    assert b"private" not in blob
    assert b"health" not in blob
    assert blob[:6] == b"KAIRO1"


def test_sync_id_is_stable_and_opaque():
    a = crypto.sync_id_for("my passphrase")
    b = crypto.sync_id_for("my passphrase")
    assert a == b
    assert "passphrase" not in a
    assert a != crypto.sync_id_for("different")


# --------------------------------------------------------------------------- #
# Snapshot + full encrypt/decrypt of a real store
# --------------------------------------------------------------------------- #
def test_snapshot_export_and_encrypted_roundtrip():
    db.init_db()
    chunk = EnrichedChunk(
        text="export me — bloated after lentils",
        timestamp=datetime.now(timezone.utc), source_type=SourceType.TEXT,
        session_id=new_id(), chunk_index=0, vector=[0.1] * config.EMBED_DIM,
        model_name="t", domains=["Health"], confidence=0.9,
        emotional_tone=ToneType.NEUTRAL, word_count=5,
    )
    vectors.add_chunks([chunk])

    snap = snapshot.export_snapshot()
    assert chunk.chunk_id in snap["memories"]["ids"]
    assert any("export me" in d for d in snap["memories"]["documents"])

    # Encrypt the whole snapshot and decrypt it back.
    import json
    blob = crypto.encrypt(json.dumps(snap).encode(), "pw123")
    restored = json.loads(crypto.decrypt(blob, "pw123"))
    assert chunk.chunk_id in restored["memories"]["ids"]

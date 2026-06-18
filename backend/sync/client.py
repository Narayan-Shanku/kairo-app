"""Sync client: export → encrypt → push, and pull → decrypt → import.

All encryption happens here, on the device, before anything is sent. The sync
server only ever receives an opaque ciphertext blob under a passphrase-derived id.
"""

from __future__ import annotations

import json
import os

import httpx

from backend.sync import crypto, snapshot

DEFAULT_SERVER = os.environ.get("KAIRO_SYNC_SERVER", "http://localhost:8787")


def _headers() -> dict:
    token = os.environ.get("KAIRO_SYNC_TOKEN")
    return {"Authorization": f"Bearer {token}"} if token else {}


def push(passphrase: str, server: str | None = None) -> dict:
    """Encrypt the local store and upload it. Returns a summary (no secrets)."""
    server = (server or DEFAULT_SERVER).rstrip("/")
    snap = snapshot.export_snapshot()
    blob = crypto.encrypt(json.dumps(snap).encode("utf-8"), passphrase)
    sync_id = crypto.sync_id_for(passphrase)
    resp = httpx.put(f"{server}/blob/{sync_id}", content=blob, headers=_headers(), timeout=30.0)
    resp.raise_for_status()
    return {
        "pushed": True,
        "sync_id": sync_id,
        "memories": len(snap["memories"]["ids"]),
        "encrypted_bytes": len(blob),
    }


def pull(passphrase: str, server: str | None = None) -> dict:
    """Download the encrypted blob, decrypt locally, and merge it in."""
    server = (server or DEFAULT_SERVER).rstrip("/")
    sync_id = crypto.sync_id_for(passphrase)
    resp = httpx.get(f"{server}/blob/{sync_id}", headers=_headers(), timeout=30.0)
    if resp.status_code == 404:
        return {"pulled": False, "reason": "no backup found for this passphrase"}
    resp.raise_for_status()
    snap = json.loads(crypto.decrypt(resp.content, passphrase))  # raises on wrong passphrase
    result = snapshot.import_snapshot(snap)
    return {"pulled": True, **result}

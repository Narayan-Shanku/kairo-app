"""Kairō sync server — a zero-knowledge encrypted-blob store.

This is the ONLY piece meant to be deployed to a public host. It deliberately
knows nothing about Kairō: it stores and returns opaque ciphertext blobs keyed by
an opaque id. It has no encryption key and never sees plaintext, so a breach of
this server exposes nothing readable. (Equivalent to an S3 bucket of blobs.)

Run:  uvicorn syncserver.app:app --port 8787
"""

from __future__ import annotations

import os
import re
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, Response

app = FastAPI(title="Kairō Sync", description="Zero-knowledge encrypted blob store")

STORE = Path(os.environ.get("KAIRO_SYNC_DIR", "/tmp/kairo-sync-blobs"))
STORE.mkdir(parents=True, exist_ok=True)

# Optional shared-secret token. When set, /blob/* requires Authorization: Bearer
# <token> — prevents anonymous strangers writing blobs to your store. (The data
# is already end-to-end encrypted; this is abuse/access control, not confidentiality.)
SYNC_TOKEN = os.environ.get("KAIRO_SYNC_TOKEN") or None


@app.middleware("http")
async def _auth(request: Request, call_next):
    if SYNC_TOKEN and request.url.path.startswith("/blob"):
        if request.headers.get("authorization") != f"Bearer {SYNC_TOKEN}":
            return JSONResponse({"detail": "Unauthorized"}, status_code=401)
    return await call_next(request)

MAX_BLOB_BYTES = int(os.environ.get("KAIRO_SYNC_MAX_BYTES", 50 * 1024 * 1024))  # 50 MB
_ID_RE = re.compile(r"^[A-Za-z0-9_-]{8,128}$")  # opaque ids only; blocks path traversal


def _path(sync_id: str) -> Path:
    if not _ID_RE.match(sync_id):
        raise HTTPException(status_code=400, detail="invalid sync id")
    return STORE / f"{sync_id}.blob"


@app.get("/health")
def health():
    return {"status": "ok", "blobs": len(list(STORE.glob("*.blob")))}


@app.put("/blob/{sync_id}")
async def put_blob(sync_id: str, request: Request):
    body = await request.body()
    if len(body) > MAX_BLOB_BYTES:
        raise HTTPException(status_code=413, detail="blob too large")
    if not body:
        raise HTTPException(status_code=400, detail="empty blob")
    _path(sync_id).write_bytes(body)
    return {"stored": len(body)}


@app.get("/blob/{sync_id}")
def get_blob(sync_id: str):
    path = _path(sync_id)
    if not path.exists():
        raise HTTPException(status_code=404, detail="not found")
    return Response(content=path.read_bytes(), media_type="application/octet-stream")


@app.delete("/blob/{sync_id}")
def delete_blob(sync_id: str):
    path = _path(sync_id)
    if path.exists():
        path.unlink()
    return {"deleted": True}

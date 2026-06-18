"""Kairō FastAPI application.

Exposes the internal pipeline (doc §5) as a small REST API and serves the
browser UI. Everything runs locally against Ollama + on-device storage.
"""

from __future__ import annotations

import tempfile
from pathlib import Path

import ollama
from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from backend import config, pipeline
from backend.models import SourceType
from backend.retrieval import rag
from backend.review import cards as review_cards
from backend.storage import db, vectors

app = FastAPI(title="Kairō", version="0.1.0")

FRONTEND_DIR = Path(__file__).resolve().parent.parent / "frontend"


@app.on_event("startup")
def _startup() -> None:
    db.init_db()


@app.middleware("http")
async def _auth(request: Request, call_next):
    """Bearer-token gate for /api/* when KAIRO_API_TOKEN is set (health exempt)."""
    if config.API_TOKEN:
        path = request.url.path
        if path.startswith("/api") and path != "/api/health":
            if request.headers.get("authorization") != f"Bearer {config.API_TOKEN}":
                return JSONResponse({"detail": "Unauthorized"}, status_code=401)
    return await call_next(request)


# --------------------------------------------------------------------------- #
# Request models
# --------------------------------------------------------------------------- #
class TextCapture(BaseModel):
    text: str
    source: str = "text"


class Query(BaseModel):
    question: str


class ReviewBody(BaseModel):
    rating: str  # again | hard | good | easy
    reflection: str | None = None


class PinBody(BaseModel):
    chunk_id: str | None = None
    front: str | None = None
    back: str | None = None
    domain: str = ""


class RecallResponse(BaseModel):
    memory_id: str
    response: str | None = None


class SyncBody(BaseModel):
    passphrase: str
    server: str | None = None


# --------------------------------------------------------------------------- #
# Capture
# --------------------------------------------------------------------------- #
@app.post("/api/capture/text")
def capture_text(body: TextCapture):
    try:
        source = SourceType(body.source)
    except ValueError:
        source = SourceType.TEXT
    try:
        return pipeline.ingest_text(body.text, source)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/api/transcribe")
async def transcribe(audio: UploadFile = File(...)):
    """Transcribe audio to text WITHOUT ingesting it.

    Lets clients separate transcription from capture — the iOS app uses this for
    the remote-transcription path, and swaps in on-device WhisperKit behind the
    same contract (returns plain text the client then ingests via /api/capture/text).
    """
    suffix = Path(audio.filename or "rec.webm").suffix or ".webm"
    tmp = Path(tempfile.mkstemp(suffix=suffix)[1])
    try:
        tmp.write_bytes(await audio.read())
        from backend.capture import voice

        result = voice.transcribe(str(tmp))
        return {"transcript": result.text, "duration_seconds": result.duration_seconds}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transcription failed: {e}")
    finally:
        tmp.unlink(missing_ok=True)


@app.post("/api/capture/voice")
async def capture_voice(audio: UploadFile = File(...)):
    suffix = Path(audio.filename or "rec.webm").suffix or ".webm"
    tmp = Path(tempfile.mkstemp(suffix=suffix)[1])
    try:
        tmp.write_bytes(await audio.read())
        return pipeline.ingest_voice(str(tmp), original_suffix=suffix)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:  # transcription / decode failures
        raise HTTPException(status_code=500, detail=f"Transcription failed: {e}")
    finally:
        tmp.unlink(missing_ok=True)


# --------------------------------------------------------------------------- #
# Retrieval
# --------------------------------------------------------------------------- #
@app.post("/api/query")
def query(body: Query):
    if not body.question.strip():
        raise HTTPException(status_code=400, detail="Empty question")
    return rag.query(body.question).to_dict()


@app.get("/api/search")
def search(q: str, k: int = 5):
    if not q.strip():
        raise HTTPException(status_code=400, detail="Empty query")
    return [r.to_dict() for r in rag.search_only(q, k)]


# --------------------------------------------------------------------------- #
# Browse / stats
# --------------------------------------------------------------------------- #
@app.get("/api/memories")
def memories(domain: str | None = None, limit: int = 100):
    return [r.to_dict() for r in vectors.list_memories(domain=domain, limit=limit)]


@app.get("/api/stats")
def stats():
    return {
        "total_memories": vectors.count(),
        "total_sessions": db.session_count(),
        "domains": vectors.domain_counts(),
        "recent_sessions": db.recent_sessions(limit=10),
    }


@app.get("/api/health")
def health():
    """Readiness: are the local models reachable?"""
    info: dict = {"status": "ok", "ollama": False, "models": {}}
    try:
        client = ollama.Client(host=config.OLLAMA_HOST)
        available = {m.model for m in client.list().models}
        info["ollama"] = True
        info["models"] = {
            config.LLM_MODEL: any(config.LLM_MODEL in a for a in available),
            config.EMBED_MODEL: any(config.EMBED_MODEL in a for a in available),
        }
    except Exception as e:
        info["status"] = "degraded"
        info["error"] = str(e)
    return info


# --------------------------------------------------------------------------- #
# Review cards (spaced repetition)
# --------------------------------------------------------------------------- #
@app.get("/api/cards/due")
def cards_due(limit: int = 20):
    return review_cards.due(limit=limit)


@app.get("/api/cards/stats")
def cards_stats():
    return review_cards.stats()


@app.get("/api/cards")
def cards_list(limit: int = 200):
    return db.list_cards(limit=limit)


@app.post("/api/cards/{card_id}/review")
def cards_review(card_id: str, body: ReviewBody):
    if body.rating not in review_cards.scheduler.RATINGS:
        raise HTTPException(status_code=400, detail="invalid rating")
    try:
        return review_cards.review(card_id, body.rating, body.reflection)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@app.post("/api/cards/pin")
def cards_pin(body: PinBody):
    if body.chunk_id:
        card = review_cards.pin_memory(body.chunk_id)
        if not card:
            raise HTTPException(status_code=404, detail="memory not found")
        return {"pinned": True, "card_id": card["card_id"]}
    if body.front and body.back:
        card = review_cards.pin_qa(body.front, body.back, body.domain)
        return {"pinned": True, "card_id": card["card_id"]}
    raise HTTPException(status_code=400, detail="provide chunk_id or front+back")


@app.post("/api/cards/generate")
def cards_generate(limit: int = 15):
    """Batch-distill cards from recent memories that don't have one yet."""
    have = set()
    for c in db.list_cards(limit=1000):
        have.update(x for x in (c.get("source_chunk_ids") or "").split(",") if x)
    created = 0
    for mem in vectors.list_memories(limit=limit):
        if mem.chunk_id in have:
            continue
        if review_cards.generate_from_memory(mem.text, [mem.chunk_id], mem.domains):
            created += 1
    return {"created": created}


# --------------------------------------------------------------------------- #
# Proactive Engine (streaks, Day-3 recall, weekly digest, nudges)
# --------------------------------------------------------------------------- #
@app.get("/api/proactive/today")
def proactive_today():
    from backend.proactive import nudges, recall, streaks

    return {
        "streak": streaks.streak_info(),
        "recall": recall.todays_recall(),
        "nudges": nudges.current_nudges(),
    }


@app.post("/api/proactive/respond")
def proactive_respond(body: RecallResponse):
    from backend.proactive import recall

    return recall.respond(body.memory_id, body.response or "")


@app.post("/api/proactive/dismiss")
def proactive_dismiss(body: RecallResponse):
    from backend.proactive import recall

    return recall.dismiss(body.memory_id)


@app.get("/api/digest")
def digest(refresh: bool = False):
    from backend.proactive import digest as digest_mod

    return digest_mod.generate(force=refresh)


# --------------------------------------------------------------------------- #
# Encrypted sync (client-side Argon2id + AES-256-GCM; server stores ciphertext)
# --------------------------------------------------------------------------- #
@app.post("/api/sync/push")
def sync_push(body: SyncBody):
    from backend.sync import client

    if not body.passphrase:
        raise HTTPException(status_code=400, detail="passphrase required")
    try:
        return client.push(body.passphrase, body.server)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Sync server unreachable: {e}")


@app.post("/api/sync/pull")
def sync_pull(body: SyncBody):
    from backend.sync import client

    if not body.passphrase:
        raise HTTPException(status_code=400, detail="passphrase required")
    try:
        return client.pull(body.passphrase, body.server)
    except Exception as e:
        # Wrong passphrase (GCM tag mismatch) or unreachable server.
        raise HTTPException(status_code=400, detail=f"Pull failed: {e}")


# --------------------------------------------------------------------------- #
# Demo data
# --------------------------------------------------------------------------- #
@app.post("/api/demo/seed")
def demo_seed():
    from backend import demo

    return demo.seed()


@app.get("/api/demo/status")
def demo_status():
    from backend import demo

    return {"seeded": demo.is_seeded(), "total_memories": vectors.count()}


# --------------------------------------------------------------------------- #
# Frontend
# --------------------------------------------------------------------------- #
@app.get("/")
def landing():
    return FileResponse(FRONTEND_DIR / "landing.html")


@app.get("/app")
def app_page():
    return FileResponse(FRONTEND_DIR / "index.html")


app.mount("/static", StaticFiles(directory=FRONTEND_DIR), name="static")

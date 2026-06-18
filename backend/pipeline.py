"""Ingestion pipeline — wires Capture → Structure → Storage.

This is the orchestration the doc's ``capture.ingest_*`` API implies: a single
call takes raw input through transcription (voice), chunking, embedding,
classification, enrichment, and persistence.
"""

from __future__ import annotations

from datetime import datetime, timezone

from backend.capture import text as text_capture
from backend.capture import voice as voice_capture
from backend.models import SourceType, new_id
from backend.storage import db, files, vectors
from backend.structure import chunker, enricher


def _maybe_generate_card(text: str, enriched: list, domains: list[str]) -> None:
    """Best-effort: distill a review card from a new memory. Capture must never
    fail because card generation failed, so all errors are swallowed."""
    try:
        from backend.review import cards

        cards.generate_from_memory(text, [c.chunk_id for c in enriched], domains)
    except Exception:
        pass


def _summary(session_id: str, enriched: list, source: SourceType,
             duration: float = 0.0) -> dict:
    domains: list[str] = []
    for c in enriched:
        for d in c.domains:
            if d not in domains:
                domains.append(d)
    preview = enriched[0].text[:200] if enriched else ""
    word_count = sum(c.word_count for c in enriched)
    return {
        "session_id": session_id,
        "chunk_count": len(enriched),
        "word_count": word_count,
        "domains": domains,
        "source_type": source.value,
        "duration_seconds": duration,
        "preview": preview,
    }


def ingest_text(raw: str, source: SourceType = SourceType.TEXT) -> dict:
    """Capture → structure → store a text entry. Returns a session summary."""
    cleaned = text_capture.normalize(raw)
    if not cleaned:
        raise ValueError("Empty text entry")

    session_id = new_id()
    ts = datetime.now(timezone.utc)
    chunks = chunker.chunk(cleaned)
    enriched = enricher.build_enriched_chunks(
        chunks, source_type=source, session_id=session_id, timestamp=ts
    )
    vectors.add_chunks(enriched)

    summary = _summary(session_id, enriched, source)
    db.record_session(
        session_id=session_id,
        source_type=source.value,
        word_count=summary["word_count"],
        chunk_count=summary["chunk_count"],
        preview=summary["preview"],
        timestamp=ts,
    )
    _maybe_generate_card(cleaned, enriched, summary["domains"])
    return summary


def ingest_voice(audio_path: str, original_suffix: str = ".webm") -> dict:
    """Transcribe an audio file on-device, then ingest the transcript."""
    session_id = new_id()
    ts = datetime.now(timezone.utc)

    result = voice_capture.transcribe(audio_path)
    transcript = text_capture.normalize(result.text)
    if not transcript:
        raise ValueError("Transcription produced no text")

    stored_audio = files.save_audio(audio_path, session_id, original_suffix)

    chunks = chunker.chunk(transcript)
    enriched = enricher.build_enriched_chunks(
        chunks,
        source_type=SourceType.VOICE,
        session_id=session_id,
        timestamp=ts,
        raw_ref=stored_audio,
    )
    vectors.add_chunks(enriched)

    summary = _summary(session_id, enriched, SourceType.VOICE,
                       duration=result.duration_seconds)
    summary["transcript"] = transcript
    db.record_session(
        session_id=session_id,
        source_type=SourceType.VOICE.value,
        word_count=summary["word_count"],
        chunk_count=summary["chunk_count"],
        duration_seconds=result.duration_seconds,
        preview=summary["preview"],
        timestamp=ts,
    )
    _maybe_generate_card(transcript, enriched, summary["domains"])
    return summary

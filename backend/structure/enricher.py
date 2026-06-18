"""Metadata enrichment (Technical Architecture §3.2.4).

Combines the outputs of chunking, embedding, and classification into fully
formed ``EnrichedChunk`` objects ready for storage. Adds per-chunk metadata:
word count, ordering index, session linkage, timestamps, and source type.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from backend import config
from backend.models import EnrichedChunk, SourceType
from backend.structure import classifier, embedder


def build_enriched_chunks(
    texts: list[str],
    *,
    source_type: SourceType,
    session_id: str,
    timestamp: Optional[datetime] = None,
    raw_ref: Optional[str] = None,
) -> list[EnrichedChunk]:
    """Embed, classify, and enrich a list of chunk texts into EnrichedChunks."""
    if not texts:
        return []

    ts = timestamp or datetime.now(timezone.utc)
    vectors = embedder.embed_documents(texts)

    enriched: list[EnrichedChunk] = []
    for idx, (text, vector) in enumerate(zip(texts, vectors)):
        cls = classifier.classify(text)
        enriched.append(
            EnrichedChunk(
                text=text,
                timestamp=ts,
                source_type=source_type,
                session_id=session_id,
                chunk_index=idx,
                raw_ref=raw_ref,
                vector=vector,
                model_name=config.EMBED_MODEL,
                domains=cls.domains,
                confidence=cls.confidence,
                emotional_tone=cls.tone,
                word_count=len(text.split()),
            )
        )
    return enriched

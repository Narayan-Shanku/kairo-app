"""Core data structures for the Kairō pipeline.

These mirror the data models in the Technical Architecture (§6). A chunk flows
through the pipeline gaining fields at each stage:

    TextChunk → EmbeddedChunk → EnrichedChunk → (stored)

and retrieval produces SearchResult / RAGResponse objects.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from enum import Enum
from typing import Optional


class SourceType(str, Enum):
    VOICE = "voice"
    TEXT = "text"
    PHOTO = "photo"
    CLIP = "clip"
    INTEGRATION = "integration"


class ToneType(str, Enum):
    POSITIVE = "positive"
    NEUTRAL = "neutral"
    NEGATIVE = "negative"
    MIXED = "mixed"


def _now() -> datetime:
    return datetime.now(timezone.utc)


def new_id() -> str:
    return uuid.uuid4().hex


@dataclass
class TextChunk:
    """A semantic slice of a single capture, before embedding."""

    text: str
    timestamp: datetime = field(default_factory=_now)
    source_type: SourceType = SourceType.TEXT
    session_id: str = field(default_factory=new_id)
    chunk_index: int = 0
    raw_ref: Optional[str] = None  # path to original audio/image, if any
    chunk_id: str = field(default_factory=new_id)


@dataclass
class EmbeddedChunk(TextChunk):
    """A TextChunk with its dense vector representation."""

    vector: list[float] = field(default_factory=list)
    model_name: str = ""


@dataclass
class EnrichedChunk(EmbeddedChunk):
    """A fully processed chunk, ready to persist."""

    domains: list[str] = field(default_factory=list)
    confidence: float = 0.0
    emotional_tone: ToneType = ToneType.NEUTRAL
    word_count: int = 0

    def metadata(self) -> dict:
        """Flat metadata dict for the vector store (Chroma values must be scalars)."""
        return {
            "session_id": self.session_id,
            "chunk_index": self.chunk_index,
            "timestamp": self.timestamp.isoformat(),
            "timestamp_epoch": self.timestamp.timestamp(),
            "source_type": self.source_type.value,
            "domains": ",".join(self.domains),
            "confidence": round(self.confidence, 4),
            "emotional_tone": self.emotional_tone.value,
            "word_count": self.word_count,
            "raw_ref": self.raw_ref or "",
        }


@dataclass
class SourceCitation:
    chunk_id: str
    date: str          # human-readable date, e.g. "Mar 2, 2026"
    domain: str
    snippet: str

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class SearchResult:
    chunk_id: str
    text: str
    score: float       # combined RRF + rerank score
    domains: list[str]
    timestamp: datetime
    source_type: SourceType
    session_id: str = ""

    def to_dict(self) -> dict:
        d = asdict(self)
        d["timestamp"] = self.timestamp.isoformat()
        d["source_type"] = self.source_type.value
        return d


@dataclass
class RAGResponse:
    answer: str
    sources: list[SourceCitation] = field(default_factory=list)
    confidence: float = 0.0
    query_time_ms: int = 0

    def to_dict(self) -> dict:
        return {
            "answer": self.answer,
            "sources": [s.to_dict() for s in self.sources],
            "confidence": round(self.confidence, 4),
            "query_time_ms": self.query_time_ms,
        }

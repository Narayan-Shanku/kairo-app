"""Vector store (Technical Architecture §3.3.1).

ChromaDB persists embedding vectors plus flat metadata, on-device. We supply our
own embeddings (from Ollama nomic-embed-text) rather than letting Chroma embed,
so the collection uses no embedding function. Distance is cosine.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

import chromadb

from backend import config
from backend.models import EnrichedChunk, SearchResult, SourceType

_collection = None


def get_collection():
    global _collection
    if _collection is None:
        client = chromadb.PersistentClient(path=str(config.CHROMA_DIR))
        _collection = client.get_or_create_collection(
            name=config.COLLECTION_NAME,
            metadata={"hnsw:space": "cosine"},
        )
    return _collection


def add_chunks(chunks: list[EnrichedChunk]) -> list[str]:
    """Persist enriched chunks; returns their ids."""
    if not chunks:
        return []
    col = get_collection()
    col.add(
        ids=[c.chunk_id for c in chunks],
        embeddings=[c.vector for c in chunks],
        documents=[c.text for c in chunks],
        metadatas=[c.metadata() for c in chunks],
    )
    return [c.chunk_id for c in chunks]


def _to_search_result(cid: str, doc: str, meta: dict, score: float) -> SearchResult:
    domains = [d for d in (meta.get("domains") or "").split(",") if d]
    ts_raw = meta.get("timestamp")
    try:
        ts = datetime.fromisoformat(ts_raw) if ts_raw else datetime.now()
    except ValueError:
        ts = datetime.now()
    return SearchResult(
        chunk_id=cid,
        text=doc,
        score=score,
        domains=domains,
        timestamp=ts,
        source_type=SourceType(meta.get("source_type", "text")),
        session_id=meta.get("session_id", ""),
    )


def semantic_search(query_vector: list[float], k: int) -> list[SearchResult]:
    """Cosine nearest-neighbour search. Returns results in rank order."""
    col = get_collection()
    if col.count() == 0:
        return []
    res = col.query(
        query_embeddings=[query_vector],
        n_results=min(k, col.count()),
        include=["documents", "metadatas", "distances"],
    )
    out: list[SearchResult] = []
    ids = res["ids"][0]
    docs = res["documents"][0]
    metas = res["metadatas"][0]
    dists = res["distances"][0]
    for cid, doc, meta, dist in zip(ids, docs, metas, dists):
        # cosine distance -> similarity score (higher is better)
        out.append(_to_search_result(cid, doc, meta, 1.0 - float(dist)))
    return out


def all_documents() -> tuple[list[str], list[str], list[dict]]:
    """Return (ids, documents, metadatas) for the whole collection (for BM25)."""
    col = get_collection()
    if col.count() == 0:
        return [], [], []
    res = col.get(include=["documents", "metadatas"])
    return res["ids"], res["documents"], res["metadatas"]


def get_by_id(chunk_id: str) -> Optional[SearchResult]:
    col = get_collection()
    res = col.get(ids=[chunk_id], include=["documents", "metadatas"])
    if not res["ids"]:
        return None
    return _to_search_result(
        res["ids"][0], res["documents"][0], res["metadatas"][0], 1.0
    )


def list_memories(
    domain: Optional[str] = None, limit: int = 100
) -> list[SearchResult]:
    """Chronological listing for the timeline view, newest first."""
    ids, docs, metas = all_documents()
    results = [
        _to_search_result(cid, doc, meta, 0.0)
        for cid, doc, meta in zip(ids, docs, metas)
    ]
    if domain:
        results = [r for r in results if domain in r.domains]
    results.sort(key=lambda r: r.timestamp, reverse=True)
    return results[:limit]


def domain_counts() -> dict[str, int]:
    """Count chunks per domain for the Insights view."""
    _, _, metas = all_documents()
    counts = {d: 0 for d in config.DOMAINS}
    for meta in metas:
        for d in (meta.get("domains") or "").split(","):
            if d in counts:
                counts[d] += 1
    return counts


def count() -> int:
    return get_collection().count()

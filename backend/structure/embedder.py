"""Embedding model (Technical Architecture §3.2.2).

Uses Ollama's ``nomic-embed-text`` (768-dim) running locally. nomic models are
trained with task prefixes, so documents and queries are embedded differently:
  * ingest:  "search_document: ..."
  * query:   "search_query: ..."
Vectors are L2-normalised so cosine similarity equals a dot product.
"""

from __future__ import annotations

import math

import ollama

from backend import config

_client: ollama.Client | None = None


def _get_client() -> ollama.Client:
    global _client
    if _client is None:
        _client = ollama.Client(host=config.OLLAMA_HOST)
    return _client


def _l2_normalize(vec: list[float]) -> list[float]:
    norm = math.sqrt(sum(x * x for x in vec))
    if norm == 0:
        return vec
    return [x / norm for x in vec]


def _embed(inputs: list[str]) -> list[list[float]]:
    if not inputs:
        return []
    resp = _get_client().embed(model=config.EMBED_MODEL, input=inputs)
    return [_l2_normalize(list(v)) for v in resp["embeddings"]]


def embed_documents(texts: list[str]) -> list[list[float]]:
    """Embed chunks for storage (uses the document task prefix)."""
    return _embed([f"search_document: {t}" for t in texts])


def embed_query(text: str) -> list[float]:
    """Embed a single user query (uses the query task prefix)."""
    vecs = _embed([f"search_query: {text}"])
    return vecs[0] if vecs else []

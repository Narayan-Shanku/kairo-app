"""Hybrid search (Technical Architecture §3.4, step 2).

Runs two retrievals over the user's memories and fuses them:
  * semantic  — cosine similarity in ChromaDB (top-20)
  * keyword   — BM25 over raw chunk text (top-20)
Results are merged with Reciprocal Rank Fusion (RRF) into one ranked list.
"""

from __future__ import annotations

import re

from rank_bm25 import BM25Okapi

from backend import config
from backend.models import SearchResult
from backend.storage import vectors
from backend.structure import embedder

_TOKEN_RE = re.compile(r"[a-z0-9]+")

# Common low-information words. Without this, BM25 latches onto words like "my"
# in a natural-language question and ranks irrelevant memories above real matches.
_STOPWORDS = {
    "a", "an", "the", "is", "are", "was", "were", "be", "been", "being",
    "i", "me", "my", "mine", "you", "your", "we", "our", "they", "them",
    "to", "of", "in", "on", "for", "and", "or", "it", "its", "that", "this",
    "with", "do", "did", "does", "how", "why", "what", "when", "where", "who",
    "again", "all", "at", "as", "but", "by", "from", "not", "so", "then",
    "there", "will", "would", "can", "could", "should", "about", "into", "out",
    "up", "down", "over", "under", "more", "less", "just", "really", "very",
    "had", "has", "have", "get", "got", "im", "ive", "after", "before",
}


def _stem(tok: str) -> str:
    """Tiny suffix stemmer so 'bloating'/'bloated' both reduce to 'bloat'."""
    for suf, keep in (("ing", 5), ("ed", 4), ("s", 3)):
        if tok.endswith(suf) and len(tok) > keep:
            return tok[: -len(suf)]
    return tok


def _tokenize(text: str) -> list[str]:
    toks = _TOKEN_RE.findall(text.lower())
    return [_stem(t) for t in toks if t not in _STOPWORDS]


def _bm25_search(query: str, k: int) -> list[SearchResult]:
    ids, docs, metas = vectors.all_documents()
    if not docs:
        return []
    corpus = [_tokenize(d) for d in docs]
    bm25 = BM25Okapi(corpus)
    scores = bm25.get_scores(_tokenize(query))
    ranked = sorted(range(len(docs)), key=lambda i: scores[i], reverse=True)[:k]
    results = []
    for i in ranked:
        if scores[i] <= 0:
            continue
        results.append(
            vectors._to_search_result(ids[i], docs[i], metas[i], float(scores[i]))
        )
    return results


def _rrf_merge(
    semantic: list[SearchResult], keyword: list[SearchResult]
) -> list[SearchResult]:
    """Reciprocal Rank Fusion: score = Σ 1/(k + rank) across result lists."""
    k = config.RRF_K
    fused: dict[str, float] = {}
    by_id: dict[str, SearchResult] = {}
    for ranked_list in (semantic, keyword):
        for rank, r in enumerate(ranked_list):
            fused[r.chunk_id] = fused.get(r.chunk_id, 0.0) + 1.0 / (k + rank + 1)
            by_id.setdefault(r.chunk_id, r)
    merged = []
    for cid, score in sorted(fused.items(), key=lambda x: x[1], reverse=True):
        result = by_id[cid]
        result.score = score
        merged.append(result)
    return merged


def hybrid_search(query: str) -> list[SearchResult]:
    """Semantic + keyword retrieval fused via RRF. Returns the merged ranking."""
    if vectors.count() == 0:
        return []
    qvec = embedder.embed_query(query)
    semantic = vectors.semantic_search(qvec, config.SEMANTIC_TOP_K)
    keyword = _bm25_search(query, config.BM25_TOP_K)
    return _rrf_merge(semantic, keyword)

"""RAG pipeline (Technical Architecture §3.4, steps 4-5).

Ties the retrieval layer together end to end:
    query → hybrid search → re-rank → assemble context → grounded generation

The system prompt enforces grounded generation: the model may answer only from
the supplied memories and must cite them by date, never inventing facts.
"""

from __future__ import annotations

import time
from datetime import datetime

import ollama

from backend import config
from backend.models import RAGResponse, SearchResult, SourceCitation
from backend.retrieval import rerank, search

_client: ollama.Client | None = None

_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

_SYSTEM_PROMPT = (
    "You are Kairō, a personal memory assistant.\n"
    "Answer ONLY based on the memories provided below.\n"
    "If the memories don't contain relevant info, say so.\n"
    "Always cite which memory (by date) supports your answer."
)


def _get_client() -> ollama.Client:
    global _client
    if _client is None:
        _client = ollama.Client(host=config.OLLAMA_HOST)
    return _client


def human_date(ts: datetime) -> str:
    return f"{_MONTHS[ts.month - 1]} {ts.day}, {ts.year}"


def _assemble_context(results: list[SearchResult]) -> str:
    lines = []
    for i, r in enumerate(results, start=1):
        domain = r.domains[0] if r.domains else "General"
        lines.append(f"[{i}] {human_date(r.timestamp)} ({domain}): {r.text}")
    return "\n".join(lines)


def query(question: str) -> RAGResponse:
    """Run the full RAG pipeline and return a grounded, cited answer."""
    started = time.time()

    fused = search.hybrid_search(question)
    if not fused:
        return RAGResponse(
            answer="I don't have any memories relevant to that yet. "
                   "Try recording a few check-ins first.",
            sources=[],
            confidence=0.0,
            query_time_ms=int((time.time() - started) * 1000),
        )

    ranked = rerank.rerank(fused, question)[: config.FINAL_K]
    context = _assemble_context(ranked)

    user_prompt = (
        f"MEMORIES:\n{context}\n\n"
        f"USER QUESTION: {question}"
    )

    resp = _get_client().chat(
        model=config.LLM_MODEL,
        messages=[
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
        options={"temperature": 0},
    )
    answer = resp["message"]["content"].strip()

    # The LLM sees the full top-k context, but we only surface citations for the
    # genuinely relevant memories (within half the top score) so the cited list
    # doesn't get padded with weak, off-topic matches.
    top_score = ranked[0].score if ranked else 0.0
    cited = [r for r in ranked if r.score >= 0.6 * top_score] or ranked[:1]
    sources = [
        SourceCitation(
            chunk_id=r.chunk_id,
            date=human_date(r.timestamp),
            domain=r.domains[0] if r.domains else "General",
            snippet=r.text[:200],
        )
        for r in cited
    ]
    confidence = max(0.0, min(1.0, top_score)) if ranked else 0.0

    return RAGResponse(
        answer=answer,
        sources=sources,
        confidence=confidence,
        query_time_ms=int((time.time() - started) * 1000),
    )


def search_only(question: str, k: int) -> list[SearchResult]:
    """Hybrid search + re-rank without LLM generation (doc API: retrieval.search)."""
    fused = search.hybrid_search(question)
    return rerank.rerank(fused, question)[:k]

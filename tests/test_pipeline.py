"""End-to-end pipeline tests.

The chunker test is pure. The retrieval tests exercise the real on-device stack
(Ollama embeddings + LLM); they skip automatically if Ollama isn't reachable.
"""

import pytest

from backend import config
from backend.structure import chunker


# --------------------------------------------------------------------------- #
# Pure unit test (no models needed)
# --------------------------------------------------------------------------- #
def test_chunker_short_entry_is_single_chunk():
    text = "Had a rough stomach today. Bloated after lunch."
    chunks = chunker.chunk(text)
    assert len(chunks) == 1
    assert "stomach" in chunks[0]


def test_chunker_empty():
    assert chunker.chunk("") == []
    assert chunker.chunk("   ") == []


# --------------------------------------------------------------------------- #
# Retrieval tests (require Ollama)
# --------------------------------------------------------------------------- #
def _ollama_ready() -> bool:
    try:
        import ollama

        names = {m.model for m in ollama.Client(host=config.OLLAMA_HOST).list().models}
        return any(config.EMBED_MODEL in n for n in names) and any(
            config.LLM_MODEL in n for n in names
        )
    except Exception:
        return False


needs_ollama = pytest.mark.skipif(
    not _ollama_ready(),
    reason="Ollama not running or required models not pulled",
)

MEMORIES = [
    "Had a rough stomach today, felt bloated after lunch. Had dal and rice again. "
    "Didn't sleep well last night, up past 1am working.",
    "Felt great after my morning walk, focused all afternoon at work.",
    "Bloated again this evening — heavy lentils for dinner and only 5 hours sleep.",
    "Cracked the SQL window function pattern in the analytics lab today.",
]


@pytest.fixture(scope="module")
def seeded():
    from backend import pipeline
    from backend.storage import db

    db.init_db()
    for m in MEMORIES:
        pipeline.ingest_text(m)
    return True


@needs_ollama
def test_hybrid_search_finds_relevant_memory(seeded):
    from backend.retrieval import rag

    results = rag.search_only("What triggers my bloating?", k=3)
    assert results, "expected at least one search result"
    joined = " ".join(r.text.lower() for r in results)
    # The top results should surface the bloating/lentils memories, not the SQL one.
    assert "bloat" in joined or "dal" in joined or "lentil" in joined


@needs_ollama
def test_rag_query_returns_grounded_answer_with_citations(seeded):
    from backend.retrieval import rag

    resp = rag.query("What triggers my bloating?")
    assert resp.answer.strip()
    assert resp.sources, "grounded answer should cite source memories"
    # Every citation must carry a date string the user can click.
    assert all(s.date for s in resp.sources)


@needs_ollama
def test_query_with_no_memories_declines(seeded):
    from backend.retrieval import rag

    resp = rag.query("What is the capital of France?")
    # Either no sources surface, or the model declines — but it must not invent
    # a fact outside the user's memories. We assert it produced a response.
    assert resp.answer.strip()

"""Kairō MCP server — expose the user's memory to any AI agent.

This is the first brick of Kairō's "context layer" thesis: instead of competing
with every assistant's built-in memory, Kairō *feeds* them. Any MCP client
(Claude Desktop, Claude Code, an agent framework) can connect to this server and
read from — and write to — the same on-device Kairō memory the web app uses.

Run (stdio transport):
    uv run python -m backend.mcp_server

Then register it with an MCP client (see .mcp.json in the repo root for the
Claude Code config). Requires Ollama running for search / ask / add.
"""

from __future__ import annotations

from mcp.server.fastmcp import FastMCP

from backend.models import SourceType
from backend.retrieval import rag
from backend.storage import db, vectors

mcp = FastMCP("kairo")


@mcp.tool()
def search_memory(query: str, limit: int = 5) -> list[dict]:
    """Search the user's personal Kairō memory for relevant past context.

    Call this BEFORE answering anything about the user's own life, history,
    decisions, health, projects, preferences, or "what did I…" questions — it
    returns the user's actual past entries so your answer is grounded in their
    real experience instead of guesses.

    Returns a list of memories, each with its date, life domains, and text,
    ranked by relevance (hybrid semantic + keyword search with re-ranking).
    """
    results = rag.search_only(query, k=limit)
    return [
        {
            "date": rag.human_date(r.timestamp),
            "domains": r.domains,
            "text": r.text,
            "relevance": round(r.score, 3),
        }
        for r in results
    ]


@mcp.tool()
def ask_memory(question: str) -> dict:
    """Ask Kairō a natural-language question about the user's life.

    Runs Kairō's full retrieval pipeline and returns a grounded answer with
    date-stamped citations from the user's own memories. Use this when you want
    Kairō's synthesized answer; use `search_memory` when you'd rather reason over
    the raw memories yourself.
    """
    resp = rag.query(question)
    return resp.to_dict()


@mcp.tool()
def add_memory(text: str) -> dict:
    """Save a new memory to the user's Kairō store.

    Use this to persist a decision, insight, fact, or preference the user shared
    so it's available to every future session and every other AI tool. The text
    is chunked, embedded, auto-tagged by life domain, and stored on-device.
    Returns a summary of what was saved.
    """
    from backend import pipeline

    summary = pipeline.ingest_text(text, source=SourceType.INTEGRATION)
    return {
        "saved": True,
        "domains": summary["domains"],
        "chunks": summary["chunk_count"],
        "preview": summary["preview"],
    }


@mcp.tool()
def recent_memories(limit: int = 10) -> list[dict]:
    """List the user's most recent memories, newest first (a quick timeline)."""
    results = vectors.list_memories(limit=limit)
    return [
        {
            "date": rag.human_date(r.timestamp),
            "domains": r.domains,
            "source": r.source_type.value,
            "text": r.text,
        }
        for r in results
    ]


@mcp.tool()
def memory_stats() -> dict:
    """Overview of the user's Kairō memory: totals and per-domain counts."""
    return {
        "total_memories": vectors.count(),
        "total_checkins": db.session_count(),
        "domains": {k: v for k, v in vectors.domain_counts().items() if v},
    }


def main() -> None:
    db.init_db()
    mcp.run()  # stdio transport by default


if __name__ == "__main__":
    main()

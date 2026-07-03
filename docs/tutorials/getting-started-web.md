# Getting started: the Kairō web engine

In this tutorial you will run Kairō's local web engine on your Mac, load a set
of sample memories, and ask it a question that comes back **grounded and cited**
in those memories. Everything runs locally — no accounts, no cloud calls.

By the end you will have:

- the FastAPI backend running at `http://localhost:8000`
- a memory store seeded with demo check-ins
- your first cited answer from your (demo) past
- a passing test suite

## Before you start

Install these once:

- **Python 3.11+** and [`uv`](https://docs.astral.sh/uv/)
- **ffmpeg** (used for voice capture)
- **[Ollama](https://ollama.com)** with both models pulled:

```bash
ollama pull llama3.1:8b
ollama pull nomic-embed-text
```

Open a terminal in the repository root for all of the following steps.

## 1. Install the Python dependencies

```bash
uv sync
```

`uv` creates a virtual environment and installs everything from `uv.lock`.
When it finishes you'll see a list of installed packages including `fastapi`,
`chromadb`, and `ollama`.

## 2. Start Ollama

```bash
ollama serve
```

Leave this running. (If the Ollama menu-bar app is already running, this
command reports the address is in use — that's fine, it means Ollama is
already up.)

## 3. Start the engine

In a second terminal, from the repository root:

```bash
uv run uvicorn backend.app:app --reload --port 8000
```

You'll see Uvicorn report `Application startup complete` and
`Uvicorn running on http://127.0.0.1:8000`.

This also creates Kairō's data directory at `~/.kairo` — your memories,
embeddings, and audio live there, deliberately *outside* the source tree, so
nothing personal is ever committed (see `backend/config.py`).

## 4. Open the app

Visit **http://localhost:8000/** — that's the landing page. Click through (or
go directly) to the app itself:

**http://localhost:8000/app**

You'll see the Home tab with tabs for Record, Ask, Review, Digest, Timeline,
and Insights. The store is empty, so a banner asks: *"New here? Load a sample
memory set to see Kairō in action."*

## 5. Load the demo memories

Click **Load demo memories** on the Home tab.

The engine seeds a believable multi-domain memory set — health check-ins,
career notes, learning wins, project logs — backdated over the past few weeks
so the timeline and stats look real (see `backend/demo.py`). When it finishes,
the Home tab shows recent memories and per-domain stats.

## 6. Ask your first question

Open the **Ask** tab and type:

> What triggers my bloating?

Press **Ask**. In a few seconds you get an answer synthesized from the demo
check-ins — the pattern of heavy lentils and short sleep — with the source
memories cited beneath it, each tied to a date. The answer uses *only* what's
in the store; if nothing relevant existed, Kairō would say so instead of
making something up.

That's the whole loop: capture → structure → storage → retrieval, all local.

## 7. Run the tests

```bash
uv run --extra dev pytest
```

All **24 backend tests** run: pipeline, retrieval, review, proactive engine,
sync crypto, and auth. The retrieval tests need Ollama and skip themselves
automatically if it isn't reachable — so expect a few `skipped` if you stopped
`ollama serve`.

## Where to go next

- **[Plug your memory into AI agents](../MCP_SETUP.md)** — the same `~/.kairo`
  store can serve as a context layer for Claude Code or Claude Desktop over MCP.
- **[Deployment & encrypted sync](../DEPLOYMENT.md)** — self-host the stack,
  add a bearer token, and sync between devices with zero-knowledge encryption.
- **[Getting started on iOS](getting-started-ios.md)** — run the fully
  standalone on-device version on an iPhone.

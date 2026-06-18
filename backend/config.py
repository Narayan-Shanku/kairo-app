"""Central configuration and on-device storage layout for Kairō.

Everything Kairō persists lives under ``~/.kairo`` (see architecture doc §3.3.3),
deliberately *outside* the source tree so user memories are never committed.
Importing this module ensures those directories exist.
"""

from __future__ import annotations

import os
from pathlib import Path

# ---------------------------------------------------------------------------
# Storage layout (mirrors Technical Architecture §3.3.3)
# ---------------------------------------------------------------------------
KAIRO_HOME = Path(os.environ.get("KAIRO_HOME", Path.home() / ".kairo"))
AUDIO_DIR = KAIRO_HOME / "audio"          # raw voice recordings
PHOTOS_DIR = KAIRO_HOME / "photos"        # screenshots / images (Milestone 2)
EXPORTS_DIR = KAIRO_HOME / "exports"      # user-initiated data exports
CHROMA_DIR = KAIRO_HOME / "chroma"        # ChromaDB persistence
DB_PATH = KAIRO_HOME / "kairo.db"         # SQLite metadata / sessions
CONFIG_PATH = KAIRO_HOME / "config.yaml"  # user preferences (optional)

for _d in (KAIRO_HOME, AUDIO_DIR, PHOTOS_DIR, EXPORTS_DIR, CHROMA_DIR):
    _d.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# Models — all served locally by Ollama / faster-whisper (no cloud, no keys)
# ---------------------------------------------------------------------------
# Optional bearer token. When set (e.g. on a publicly-exposed deployment), all
# /api/* calls (except /api/health) must send `Authorization: Bearer <token>`.
# Unset locally → no auth, so local dev is unaffected.
API_TOKEN = os.environ.get("KAIRO_API_TOKEN") or None

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
EMBED_MODEL = os.environ.get("KAIRO_EMBED_MODEL", "nomic-embed-text")
EMBED_DIM = 768  # nomic-embed-text output dimensionality
LLM_MODEL = os.environ.get("KAIRO_LLM_MODEL", "llama3.1:8b")
WHISPER_MODEL = os.environ.get("KAIRO_WHISPER_MODEL", "base.en")
WHISPER_COMPUTE = os.environ.get("KAIRO_WHISPER_COMPUTE", "int8")

# ---------------------------------------------------------------------------
# Domains (Technical Architecture §3.2.3) — fixed taxonomy for tagging
# ---------------------------------------------------------------------------
DOMAINS = [
    "Health",
    "Career",
    "Learning",
    "Projects",
    "Fitness",
    "Finance",
    "Relationships",
]

# Keyword hints used to bias / short-circuit the LLM classifier (doc §3.2.3).
DOMAIN_KEYWORDS = {
    "Health": ["food", "sleep", "symptom", "medication", "energy", "pain",
               "doctor", "bloat", "stomach", "headache", "diet", "sick"],
    "Career": ["job", "interview", "resume", "salary", "manager", "promotion",
               "linkedin", "networking", "career"],
    "Learning": ["study", "course", "concept", "practice", "tutorial",
                 "module", "textbook", "lab", "learn", "read"],
    "Projects": ["build", "code", "deploy", "bug", "feature", "deadline",
                 "sprint", "hackathon", "project", "ship"],
    "Fitness": ["workout", "run", "gym", "reps", "sets", "cardio", "walk",
                "lift", "exercise", "stretch"],
    "Finance": ["budget", "savings", "investment", "expense", "income",
                "rent", "loan", "money", "spend"],
    "Relationships": ["family", "friend", "partner", "conversation", "conflict",
                      "support", "social", "mentor", "wife", "husband"],
}

# ---------------------------------------------------------------------------
# Chunking (doc §3.2.1)
# ---------------------------------------------------------------------------
CHUNK_MAX_TOKENS = 512
CHUNK_MIN_TOKENS = 256
CHUNK_OVERLAP_TOKENS = 64
# Rough chars-per-token heuristic for token estimation without a tokenizer dep.
CHARS_PER_TOKEN = 4

# ---------------------------------------------------------------------------
# Retrieval (doc §3.4)
# ---------------------------------------------------------------------------
SEMANTIC_TOP_K = 20      # cosine candidates from ChromaDB
BM25_TOP_K = 20          # keyword candidates
RRF_K = 60               # Reciprocal Rank Fusion constant
FINAL_K = 5              # chunks assembled into the generation context
DOMAIN_BOOST = 0.15      # added when query domain matches chunk domain
RECENCY_HALFLIFE_DAYS = 90
SESSION_DIVERSITY_PENALTY = 0.10  # subtract for repeated chunks from one session

# Vector store collection name (single-tenant: one collection per user/device).
COLLECTION_NAME = "kairo_memories"

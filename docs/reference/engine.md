# Engine reference: retrieval and generation parameters

Exact parameters of Kairō's retrieval and generation engines on both platforms: the fully on-device iOS app and the optional Python/FastAPI backend. Values below are taken from the source files listed in each section. For the surrounding architecture, see [`../MOBILE_ARCHITECTURE.md`](../MOBILE_ARCHITECTURE.md).

## iOS retrieval

Sources: `ios/Kairo/Core/Repositories/LocalMemoryRepository.swift`, `ios/Kairo/Core/Services/EmbeddingService.swift`.

### Chunking and embeddings

| Parameter | Value |
|---|---|
| Chunker | `TextChunker` — `NLTokenizer` sentence split |
| Whole-entry threshold | Entries **< 200 chars** are stored as a single chunk |
| Fragment merge | Sentences **< 40 chars** are merged into the previous chunk |
| Embedding model | Apple `NLEmbedding.sentenceEmbedding(for: .english)` (built-in, no download) |
| Embedding input | Lowercased text |
| Vectors stored | One whole-entry vector always; per-chunk vectors only when chunking yields > 1 piece |
| Similarity | Cosine; a memory's semantic score = **best cosine over its chunks** (whole-entry vector as fallback) |

### Hybrid ranking

| Parameter | Value |
|---|---|
| Semantic list | Memories with best-chunk cosine > 0, descending |
| Keyword list | Memories ranked by count of overlapping stemmed query tokens |
| Tokenizer | Lowercase, split on non-alphanumerics, tokens ≤ 2 chars dropped, then stemmed |
| Stemmer suffixes (in order) | `ing`, `edly`, `ed`, `ies`, `es`, `ment`, `ly`, `s` — stripped only when `word.count > suffix.count + 2` |
| Fusion | Reciprocal Rank Fusion, **k = 60**: score = Σ 1/(60 + rank), rank 1-based |
| Context size | **Top 5** fused memories go into the prompt |
| Empty-fusion fallback | Most-recent ordering (keeps offline search non-empty) |
| Relevance floor (Ask only) | Any keyword hit in any memory **OR** best-chunk cosine **≥ 0.15**; otherwise a fixed "I don't have anything relevant to that yet" reply, confidence 0 |
| Per-memory prompt cap | **600 chars** (Ask) / **400 chars** (Digest, in `LocalProactiveRepository.swift`) |
| Source snippet length | 200 chars |

## iOS generation chain

Sources: `ios/Kairo/Core/Services/GenerationService.swift`, `ios/Kairo/Config/AppConfig.swift`.

Every generation call (Ask answers, weekly digest, recall prompts, card distillation) walks the same chain and stops at the first tier that returns text:

| Tier | Component | Availability condition |
|---|---|---|
| 1 | `GenerationService` — Apple Foundation Models (`SystemLanguageModel` / `LanguageModelSession`) | iOS 26+ on an Apple Intelligence device; `.available` at call time |
| 2 | `CloudGenerationService` — stateless proxy (see [Proxy API contract](#proxy-api-contract)) | `AppConfig.cloudGenerationURL != nil` **AND** the `cloudAnswersEnabled` setting is on (defaults on); 30 s timeout; non-2xx or empty answer → nil |
| 3 | Extractive / template fallback | Always — Ask returns a bulleted list of the top memories; Digest returns a per-domain count summary |

Only the already-built prompt (top-k snippets + question) is ever sent to tier 2; raw memories, embeddings, and the store never leave the device.

The committed `ios/Kairo/Config/AppConfig.swift` has `cloudGenerationURL` and `cloudGenerationToken` set to `nil` by convention: real values (`<your-proxy-url>`, `<token>`) are kept as a local-only, never-committed diff.

### Confidence field (`RAGResponse.confidence`)

| Value | Meaning |
|---|---|
| `1` | Generated answer (on-device or cloud) |
| `0.5` | Extractive fallback (relevant memories listed, no model) |
| `0` | No memories, or relevance floor not met |

## iOS card generation

Source: `ios/Kairo/Core/Repositories/LocalCardRepository.swift`.

| Parameter | Value |
|---|---|
| Verdict format | JSON only: `{"type": "insight" \| "decision" \| "none", "front": "...", "back": "...", "confidence": 0.0}` |
| Entry cap in prompt | 2000 chars |
| Acceptance gate | `type` is `insight` or `decision`, non-empty `front` and `back`, **confidence ≥ 0.6** (same bar as the backend) |
| Dedup | Memory id added to the `card_attempted` set **before** distilling, so concurrent passes never double-process |
| Transient failure | No verdict from any generator (tier 1 and 2 both nil) → the mark is released and the memory is retried on a later pass |
| Unparseable verdict | Model replied but no decodable JSON → settled `notCardworthy`; stays marked, never retried |
| Candidate order | Newest memories first, up to the pass limit; skipped entirely when no generator is available |
| New-card schedule | Due **immediately** (`dueDate = now`), ease 2.5, interval 0, repetitions 0 |
| Decision-card reflections | A non-empty reflection at review time is written back as a **new memory** (`createdMemory: true`) |

## SM-2 scheduler (both platforms)

Sources: `ios/Kairo/Core/Utils/SM2.swift`, `backend/review/scheduler.py` (identical algorithm).

| Rating | Quality `q` |
|---|---|
| Again | 2 |
| Hard | 3 |
| Good | 4 |
| Easy | 5 |

| Rule | Value |
|---|---|
| Ease update | `ease + (0.1 − (5−q)·(0.08 + (5−q)·0.02))` |
| Ease floor / default | **1.3** / **2.5** |
| Lapse (`q < 3`) | Interval resets to **1 day**, repetitions reset to 0, lapses + 1 |
| Interval, repetition 0 | 1 day |
| Interval, repetition 1 | 6 days |
| Interval, repetition ≥ 2 | `round(interval × ease)` days |
| Next due date | now + interval days (computed by the caller) |

## Server retrieval

Sources: `backend/config.py`, `backend/retrieval/search.py`, `backend/retrieval/rerank.py`, `backend/retrieval/rag.py`, `backend/structure/embedder.py`.

| Constant (`backend/config.py`) | Value | Role |
|---|---|---|
| `SEMANTIC_TOP_K` | 20 | Cosine candidates from ChromaDB |
| `BM25_TOP_K` | 20 | Keyword candidates (`rank_bm25` BM25Okapi, stopword-filtered + stemmed) |
| `RRF_K` | 60 | Reciprocal Rank Fusion constant |
| `FINAL_K` | 5 | Chunks assembled into the generation context |
| `DOMAIN_BOOST` | 0.15 | Added when the query's detected domain matches a chunk's domain; also the weight of the recency term |
| `RECENCY_HALFLIFE_DAYS` | 90 | Recency term = `DOMAIN_BOOST × 0.5^(age_days / 90)` |
| `SESSION_DIVERSITY_PENALTY` | 0.10 | Subtracted per repeated chunk from the same check-in session |

Embeddings: Ollama `nomic-embed-text`, **768-dim** (`EMBED_DIM`), L2-normalised, with nomic task prefixes — `search_document: ` at ingest, `search_query: ` at query time.

Generation (`backend/retrieval/rag.py`): Ollama `LLM_MODEL` (default `llama3.1:8b`), temperature 0, with a system prompt that restricts answers to the supplied memories and requires date citations. RRF scores are normalised to [0, 1] before the rerank boosts; response `confidence` = top rerank score clamped to [0, 1]. Cited sources are trimmed to results scoring **≥ 0.6 × the top score** (minimum one), each with a 200-char snippet.

## Proxy API contract

Source: `proxy/worker.js` (Cloudflare Worker; see also `proxy/README.md`).

| Aspect | Value |
|---|---|
| Endpoint | `POST /` at `<your-proxy-url>`, body `{"prompt": "..."}` |
| Auth | `Authorization: Bearer <token>` — required iff the `SHARED_TOKEN` secret is set |
| Upstream | Anthropic Messages API, `anthropic-version: 2023-06-01`, **`max_tokens: 1024`**, single user message |
| System prompt | None, by design — the app's prompts (Ask / Digest / card distillation) are self-contained, and the proxy forwards them verbatim so on-device and cloud paths behave identically |
| State | Stateless and zero-log; only the daily-cap counter (if enabled) is written |

### Responses

| Status | Body |
|---|---|
| 200 | `{"answer": "..."}` |
| 400 | `{"error": "invalid JSON body"}` or `{"error": "empty prompt"}` |
| 401 | `{"error": "unauthorized"}` |
| 405 | `{"error": "POST only"}` |
| 429 | `{"error": "daily limit reached", "cap": <n>}` |
| 500 | `{"error": "proxy misconfigured: no API key"}` |
| 502 | `{"error": "upstream request failed" \| "upstream error", ...}` — upstream status/detail passed through |

### Environment / configuration

| Name | Kind | Meaning |
|---|---|---|
| `ANTHROPIC_API_KEY` | secret | Required; the only place the LLM key lives |
| `SHARED_TOKEN` | secret | Optional bearer gate (abuse control, not a real secret — it ships in the app binary) |
| `MODEL` | var | Model id; defaults to `claude-opus-4-8` |
| `DAILY_CAP` | var | Max forwarded requests per UTC day; enforced only when > 0 **and** `USAGE` is bound. A slot is reserved before the upstream call |
| `USAGE` | KV binding | Backs the daily-cap counter (entries expire after 48 h) |

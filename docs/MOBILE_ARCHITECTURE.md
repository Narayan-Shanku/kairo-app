# Kairō — Mobile (iOS) Architecture & Cost

How Kairō runs on iPhone, and what an MVP costs.

## The core constraint

iOS can't run our Mac stack (Python / Ollama / ChromaDB) directly. Capture,
embeddings, vector search, and re-ranking all port fine to on-device; the only
hard part is **where the LLM runs**. That single decision shapes the architecture.

## Layer mapping (Mac → iPhone)

| Layer | Today (Mac) | iPhone equivalent |
|---|---|---|
| App shell | Browser + FastAPI | **SwiftUI** (native) |
| Voice capture | MediaRecorder + faster-whisper | `AVAudioRecorder` + **WhisperKit** (Core ML, on-device) |
| Embeddings | Ollama `nomic-embed-text` | BGE/GTE-small via **Core ML / MLX**, on-device |
| Domain tagging | `llama3.1` JSON | small on-device model / rules |
| Vector store | ChromaDB | **`sqlite-vec`** (or brute-force cosine; store is small) |
| Metadata | SQLite | **GRDB** / SwiftData |
| Hybrid search + rerank | Python | Swift port of the same logic |
| Generation (LLM) | Ollama `llama3.1:8b` | **the decision** (below) |
| Sync | — | **CloudKit** private DB (E2E) or S3 + AES-256-GCM |
| Proactive (Day-3, nudges) | in-process | **APNs** + BGTaskScheduler |
| Agent layer (MCP) | local MCP server | hosted MCP over the user's synced memory |

## The LLM decision

| Option | How | Privacy | Quality/UX | Effort | Verdict |
|---|---|---|---|---|---|
| A — Thin client + hosted backend | phone = UI, our FastAPI hosted | ❌ raw data leaves device | ✅ fast, good | Low | **MVP starts here** |
| B — Fully on-device | small model via MLX/llama.cpp | ✅ max | ⚠️ slower, newer phones | High | premium toggle later |
| C — Hybrid (privacy-preserving cloud inference) | on-device capture/storage/retrieval; only top-k context + question → stateless, zero-log endpoint | ✅ raw stays on device | ✅ full quality | Medium | **the target** |

## Recommended architecture (Option C)

```
┌──────────── iPhone (SwiftUI) ────────────┐
│ Capture   AVAudioRecorder → WhisperKit   │
│ Structure Core ML/MLX embedder · tagging │
│ Storage   sqlite-vec · GRDB · sandbox    │
│ Retrieval hybrid + RRF + rerank  (LOCAL) │
│ Review    SM-2 (port of backend/review)  │
└──────┬───────────────────────┬───────────┘
 top-k │+ question (TLS)        │ encrypted blobs
       ▼                        ▼
 stateless inference     E2E-encrypted sync
 (Ollama/vLLM, no logs)  (CloudKit / S3+AES)
```

## MVP cost map

The only **required** paid item is the **Apple Developer Program — $99/year**
(for device installs / TestFlight / push / CloudKit). Everything else is free:

| Component | Free option |
|---|---|
| Xcode, Swift, Simulator | ✅ free |
| WhisperKit, Core ML/MLX embedder, sqlite-vec, GRDB | ✅ free / open source |
| Sync (CloudKit private DB) | ✅ free tier (generous) |
| Push (APNs), TestFlight | ✅ free with dev account |
| **LLM generation** | ✅ free via on-device small model (MLX) **or** self-host on the founder's existing Mac (free tunnel) |

Paid infra only enters when you outgrow "runs on the founder's Mac + the user's
phone" — then a small always-on inference host (~$5–40/mo VPS or pennies-per-use
serverless GPU).

## Phasing

1. **iOS MVP — Option A (current):** native SwiftUI thin client to the FastAPI
   backend. Scaffolded in `ios/` (Home · Capture · Ask · Review). Proves the
   mobile UX fast. _(See `ios/README.md`.)_
2. **Privacy-grade — Option C:** move capture + embeddings + retrieval on-device;
   generation on a stateless endpoint.
3. **Differentiators:** on-device-only LLM toggle (MLX) + CloudKit E2E sync so
   Mac, iPhone, and agents share one memory.

## Framework call

Native **SwiftUI** for iOS v1 (best for the on-device ML path: WhisperKit, Core
ML, MLX, CloudKit, APNs are all first-class). Reconsider Flutter only if Android
parity becomes an early hard requirement.

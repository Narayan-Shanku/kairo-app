# Design decisions

A decision log for Kairō's iOS app — why the codebase is the way it is, what each choice traded away, and what was considered instead. Dates and session numbers refer to `BUILD_LOG.md` at the repo root; the original architecture analysis is in [MOBILE_ARCHITECTURE.md](../MOBILE_ARCHITECTURE.md).

## 1. Standalone on-device, with a cloud fallback (Option A → Option C)

The mobile architecture doc framed the whole design around one question: *where does the LLM run?* Three options were on the table — **A**, a thin SwiftUI client to the existing FastAPI backend (fast, but raw data leaves the device); **B**, a fully on-device small model (maximum privacy, slow, newest phones only); **C**, hybrid — capture, embedding, storage, and retrieval on-device, with only the top-k snippets plus the question sent to a stateless inference endpoint.

The app *started* as Option A (Session 5) because it proved the mobile UX in one session against an engine that already worked. Two things then changed the calculus. First, iOS 26's Apple Foundation Models made on-device generation free — no model download, no MLX integration — so Session 13 flipped the app to fully standalone (`AppConfig.standalone = true` swaps in local repositories; the protocol-based MVVM meant the UI and ViewModels were untouched). Second, Foundation Models only run on Apple-Intelligence hardware (iPhone 15 Pro and later), which would have left iPhone 11–14 and SE users with extractive answers only. Session 21 closed that reach gap with a stateless cloud proxy (`proxy/worker.js`) as a middle fallback.

The landed shape is exactly Option C's triangle resolved in order: **privacy** (the memory store never leaves the phone — only an already-built prompt of retrieved snippets), then **quality** (generated, grounded answers on every device), then **reach** (older iPhones get the cloud path, with a Settings opt-out and an extractive last resort). The fallback chain in `ios/Kairo/Core/Repositories/LocalMemoryRepository.swift` is Foundation Models → cloud proxy → extractive recall.

## 2. A JSON file instead of SwiftData, Core Data, or SQLite

`ios/Kairo/Core/Storage/OnDeviceStore.swift` persists the entire store — memories with embeddings, cards with SM-2 state, review and check-in dates, prefs — as one JSON file in Documents. That is not what the architecture doc originally proposed (`sqlite-vec` + GRDB/SwiftData), and the reason is empirical, not aesthetic: the first offline-cache implementation (Session 7) used SwiftData, and it `SIGTRAP`'d on basic `ModelContext` fetch/insert/save on the main thread in Xcode 26.5 — with bare `@Model` classes, a fresh store, and no diagnosable message. An undiagnosable crash in the persistence layer of a memory app is disqualifying, so the code pivoted to plain `Codable` + a JSON file.

The JSON store then earned its keep on reliability details a heavier stack would have made harder:

- **Tolerant decoding** — `Snapshot.init(from:)` uses `decodeIfPresent` for every field, so adding a field (as `checkInDates` was in Session 19) never wipes an older store.
- **Atomic writes** — every save uses `.atomic`, so a crash mid-write can't half-corrupt the file.
- **Corrupt-store protection** — an undecodable file is moved aside to `kairo-store.corrupt.json` instead of being silently overwritten by the next save (which would have been permanent data loss).

The known cost is that every mutation rewrites the whole file. At demo scale (tens to low hundreds of memories, each with embedding vectors) this is invisible; at ~500+ memories it will hitch. That refactor is deliberately on the books (see §8) rather than done speculatively.

## 3. Retrieval: NLEmbedding, chunking, hybrid RRF, and a permissive floor

On-device retrieval (Session 21, in `LocalMemoryRepository`) is a pragmatic port of the server's stack, with each piece chosen for a reason:

- **`NLEmbedding` for vectors** — Apple's built-in sentence embeddings ship with iOS, so there is no model download, no first-run wait, and no storage cost. Lower quality than a dedicated embedder, which is why it isn't asked to carry retrieval alone.
- **Sentence chunking on capture** — long entries embed per-chunk (`OnDeviceStore.Chunk`) and score by best chunk, so a two-minute voice ramble can still match a question about one sentence in it. Pre-chunk stores still work: `chunks == nil` falls back to the whole-entry embedding.
- **Hybrid search fused with RRF (k = 60)** — a pure-semantic ranker is weak exactly where a memory app hurts most: names, medications, exact product terms. A keyword ranking (with the backend's light suffix stemmer, so `bloating`/`bloated` → `bloat`) runs alongside the semantic one, and Reciprocal Rank Fusion merges them so an exact-term hit can outrank a vaguely-similar embedding.
- **A conservative relevance floor** — `hasRelevant` short-circuits to an honest "I don't have anything relevant to that yet" instead of forcing unrelated memories on the model. The floor is deliberately permissive (a keyword hit *or* a best-chunk cosine ≥ 0.15): its job is to catch clearly-off-topic questions only, because the grounding prompt — "Answer ONLY using the memories below … if they don't contain relevant info, say so" — is the fine relevance filter. A strict floor would silently eat good queries; a permissive one just hands the judgment to the layer better equipped to make it.

## 4. Card generation: conservative distillation with an "attempted" ledger

Review cards are distilled from memories by an LLM verdict (`LocalCardRepository.generateMissing`): each memory yields `insight`, `decision`, or `none` as JSON with a confidence score, gated at **confidence ≥ 0.6**, and the prompt explicitly instructs "Be conservative — prefer `none`." The reasoning: a spaced-repetition deck is only valuable if the user trusts that everything in it is worth their attention. A spammy deck ("had a coffee, it was fine" → flashcard) trains the user to skip Review, which kills the retention loop the feature exists to power. Missing a marginal card costs little; polluting the deck costs the habit.

The **"attempted" ledger** (`cardAttempted` in `OnDeviceStore`) exists because generation is triggered opportunistically — from Home in the background and from Review on open — so the same memory would otherwise be re-distilled on every pass, burning generation calls and risking duplicate cards. Each memory is marked *before* distillation so the dedup holds across concurrent calls. The mark's fate then depends on *why* nothing was created: a definitive "not cardworthy" verdict is settled knowledge and stays marked forever, while a transient failure (no generator available, network error) releases the mark so the memory is retried on a later pass. Conflating those two — the obvious simpler design — would either retry settled verdicts forever or permanently skip memories that just hit a network blip.

## 5. A task-agnostic cloud proxy (no system prompt)

`proxy/worker.js` deliberately sets **no system prompt**: its contract is `{prompt} → {answer}`, forwarded verbatim to the Claude Messages API. Three generation tasks share it — Ask, the weekly Digest, and card distillation — and each app-side prompt is fully self-contained. Since the on-device Foundation Models path also runs prompt-only (`LanguageModelSession().respond(to:)`), keeping the proxy prompt-free makes the two paths symmetric: the same prompt produces comparable output whether it runs on the phone or in the cloud, and a Q&A-flavored system prompt can't bias the card-distillation JSON or the digest.

The proxy's other properties follow from "stateless abuse-controlled endpoint": it stores nothing, requires a bearer `SHARED_TOKEN` (a shipping-in-the-binary abuse gate, not a real secret), and enforces a KV-backed global daily cap whose slot is reserved *before* the paid upstream call so the cost ceiling holds even when requests fail. Model and cap are one-line `wrangler.toml` changes; the live deployment uses `claude-haiku-4-5` (started on an Opus-class model, switched after a quality check showed Haiku sufficient at ~1.3 s round-trip). By convention, the committed `ios/Kairo/Config/AppConfig.swift` holds `nil` for `cloudGenerationURL` and `cloudGenerationToken` — the real values exist only as a local, uncommitted diff, verified absent from git history.

## 6. Free-team constraints as design inputs

The app was built and sideloaded on a **free** Apple developer team (see [How to sideload onto an iPhone](../how-to/sideload-iphone.md)), and one capability gap on free teams — no App Groups — was treated as a design input rather than a blocker. The streak state that check-in reminders need is published to `UserDefaults.standard`, *not* to the App Group container, precisely so `NotificationService` works on a free-team device build. The widget (`ios/KairoWidget/`) is the one feature that genuinely cannot avoid the App Group — the app and the extension are separate processes and `group.com.kairomemory.kairo` is the only sanctioned bridge — so the widget is the only paid-gated feature, and it was verified in the Simulator (where App Groups work without entitlement provisioning) per the "build now, verify in Simulator" call in Session 19.

## 7. Notification permission asked in context, not at launch

The Session 21 pre-submission audit moved the notification permission prompt out of app launch. `NotificationService.bootstrap()` now never prompts — it only reschedules if already authorized — and the first ask happens in `requestAuthorizationIfNeeded()`, called after the user's **first check-in** (`HomeViewModel.checkIn`). This follows the Human Interface Guidelines' direction to request permission in the context that explains it, and the conversion logic is concrete: at launch, "Kairō would like to send you notifications" is an unmotivated interruption; right after a check-in, the user has just created a streak that an evening reminder demonstrably protects. Since iOS makes a denial nearly irreversible in-app, the design also accepts denial gracefully — Settings explains the state and deep-links to iOS Settings rather than re-prompting.

## 8. Deferred and dropped

Session 21's closing call was that shipping a complete, honest v1 beat finishing every known improvement. **Deferred** (real, documented, intentionally not blocking release):

- **Store persistence refactor** — the whole-file JSON rewrite per mutation (§2); fine at demo scale, revisit around ~500+ memories.
- **WhisperKit download gate** — WhisperKit lazily downloads its `base` model, but it is only the fallback transcription engine behind on-device `SFSpeechRecognizer`, so a first-run download prompt wasn't worth v1 surface area.
- **Settings theming under Sunset** — a cosmetic gap in the hero theme.
- **iOS↔server sync client** — the zero-knowledge sync protocol is verified web↔server; the Swift client (CryptoKit AES-GCM plus an Argon2 package) remains future work.

**Dropped by choice** (not deferred): multimodal capture (photo/OCR). The voice-and-text loop — capture, ask, review, streak — is a complete product without it, and multimodal would have added a large capture-pipeline surface for a feature no core loop depends on.

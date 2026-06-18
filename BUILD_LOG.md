# Kairō — Build Log

> Living documentation of what we've built. **Updated every working session.**
> Newest entries at the top. Dates are absolute.

---

## Current state at a glance

| Area | Status |
|------|--------|
| Core memory engine (Capture → Structure → Storage → Retrieval) | ✅ Working |
| Local web app (landing page + app, fully on-device) | ✅ Working |
| Grounded, cited RAG answers (no hallucination) | ✅ Working |
| MCP server (memory as a context layer for any AI agent) | ✅ Working, manual register |
| Memory Review — spaced-repetition flashcards (SM-2) | ✅ Working |
| Demo data seeding | ✅ Working |
| Tests | ✅ 24 backend (pytest) + 29 iOS (Swift Testing) passing |
| iOS app — MVVM · WhisperKit · offline cache · light/dark · proactive | ✅ Builds, runs, verified |
| **Standalone on-device iOS** (Foundation Models + NLEmbedding, no backend) | ✅ Built, tested, **sideloaded & running on a physical iPhone 17 Pro Max** |
| Proactive Engine — streaks · Day-3 recall · weekly digest · nudges | ✅ Working (web + iOS) |
| Streak widget — "Kairo the sun" mascot + explicit check-in (WidgetKit, App Group) | ✅ Built + verified in Simulator (device needs paid account) |
| Check-in reminders — local evening nudge + Settings toggle/time (on-device) | ✅ Built + UI verified; works on free-team device (no App Group needed) |
| Encrypted sync (zero-knowledge) + deployable sync server | ✅ Verified e2e (web ↔ server); iOS client pending |
| Deployment — Docker/compose · token auth · deploy configs | ✅ Verified locally; cloud provisioning = user |
| Multi-modal (photo/OCR), browser extension, sync, mobile, enterprise | ⏳ Not started |

**Stack:** Python 3.13 · FastAPI · ChromaDB · SQLite · faster-whisper · Ollama
(`llama3.1:8b` generation, `nomic-embed-text` embeddings) · vanilla HTML/CSS/JS
frontend · MCP Python SDK. Fully local — no cloud, no API keys. Data lives in
`~/.kairo`.

**Run:**
- Web app: `uv run uvicorn backend.app:app --reload --port 8000` → landing at `/`, app at `/app`
- MCP server: `uv run python -m backend.mcp_server` (see `docs/MCP_SETUP.md`)
- Tests: `uv run --extra dev pytest`

---

## 2026-06-18 — Session 19: Streak widget + "Kairo the sun" mascot

A Duolingo-style streak layer: a home-screen widget with a mascot whose mood
tracks your streak, plus an explicit daily check-in.

- **Mascot — "Kairo the sun":** the brand half-disc ◐ given a face, drawn entirely
  in SwiftUI (`KairoSun`, 4 moods). **Beaming** (coral sun + rays, checked in today),
  **content** (streak alive, daytime), **worried** (setting sun, frown — streak at risk
  this evening), **asleep** (sleepy crescent moon + zzz — streak broken). Mood is
  derived from the snapshot + the current time so it shifts through the day.
- **Streak was already implemented** (computed from capture-days). Per the user's
  choice we kept that AND added an **explicit check-in**: `OnDeviceStore.checkInDates`,
  `ProactiveRepository.checkIn()`, and the streak now unions capture-days + check-in-days.
  Home shows a prominent mascot header with a **Check in** button.
- **Widget (WidgetKit):** `KairoWidget` extension (small + medium), `TimelineProvider`
  reads a `StreakSnapshot` the app publishes to a shared **App Group**
  (`group.com.kairomemory.kairo`) on every load/check-in (+ `WidgetCenter` reload).
  Widget view shared with the app via `StreakWidgetContent`, so Settings shows a
  **live in-app preview** of both sizes (also helps users discover the widget).
- **Backward-compat fix:** `OnDeviceStore.Snapshot` now decodes with `decodeIfPresent`
  so adding `checkInDates` (or any future field) won't wipe older stores.
- **Verified in Simulator:** app + widget build clean; App Group bridge confirmed
  (snapshot written to the shared container); mascot renders in both the worried
  (Home) and beaming (Settings preview) states.
- **Device note:** App Groups need a **paid Apple Developer account**, so the widget
  runs on the physical iPhone only after upgrading from the free team (per the user's
  "build now, verify in Simulator" choice). The standalone app itself is unaffected.
- **Check-in reminders (local notifications):** `NotificationService` (UserNotifications)
  schedules the next 3 evening nudges; today's is skipped if you've already checked in
  or the time has passed. Copy is streak-aware ("Check in to keep your N-day streak").
  Rescheduled on every streak update (`publish()`) and app open (`bootstrap()` also
  requests permission). **Settings → Reminders**: a toggle + a "Remind me at" time
  picker (`@AppStorage` remindersEnabled/reminderHour, default on / 7 PM). Streak state
  is read from `UserDefaults.standard` (not the App Group), so **reminders work on the
  free-team device too** — no paid account needed (only the widget does).

## 2026-06-18 — Session 18: First run on a physical device (sideload)

Kairō now runs **natively on a real iPhone 17 Pro Max** (iOS 26.5.1) — fully
standalone, no server, no simulator. First time on real hardware.

- **Signing:** enabled automatic signing (`CODE_SIGN_STYLE: Automatic` in `project.yml`).
  Device prepared (Developer Mode on), Apple ID signed into Xcode → Xcode auto-created
  the **Apple Development** cert + an `iOS Team Provisioning Profile` via
  `xcodebuild -allowProvisioningUpdates`.
- **Bundle ID changed:** `com.kairo.app` was already registered to another Apple
  account (globally unique) and couldn't be claimed → switched to **`com.kairomemory.kairo`**
  (display name still "Kairō"). Tests target → `com.kairomemory.kairo.tests`.
- **Codesign detritus fix (recurring):** the Desktop build dir is iCloud/fileprovider-
  watched, so the built `.app` picked up `com.apple.FinderInfo` + a `fileprovider` xattr
  → `codesign` failed ("resource fork … not allowed"). Fix: `xattr -cr` the built `.app`,
  then re-sign nested dylibs + the bundle manually with the dev identity.
- **Install/launch:** `xcrun devicectl device install app` then `… process launch`.
  First launch was blocked until the developer profile was **trusted on the phone**
  (Settings → General → VPN & Device Management). After trust → launches clean.
- **Note:** free personal team → the signed app **expires in ~7 days**; rebuild+reinstall
  to renew. Paid account removes this + unlocks TestFlight.

## 2026-06-18 — Session 17: Coastal redesign — drop amber-gold, go beachside

Reworked the entire palette away from amber-gold to a **coastal / beachside**
identity, keyed on **ocean teal**. The previous "Golden Hour" hero became **"Sunset."**

- **Why (user):** "I want light mode to be like beach side aesthetics color palette;
  as of now amber gold is more prominent in all the themes — I want to dump that."
  Confirmed direction: ocean-teal accent everywhere; hero reworked into Sunset
  (coral/peach over deep ocean) instead of gold.
- **Three coastal themes** (labels in Settings):
  - **Beachside** (light) — warm sand `#F3EEE3`, white cards, dark-teal ink, ocean-teal
    accent `#0E9C92`. Now the **default first-launch** theme.
  - **Deep Ocean** (dark) — deep teal-ink `#0A1A1C`, aqua accent `#28C2B0`.
  - **Sunset** (hero) — deep ocean lit by a **coral glow** `#FF8C6B`, peach text;
    radial coral glow via `kairoBackground()`. The signature look.
- **iOS:** `Theme.swift` palette fully reworked (all three `pick()` columns); `gold`
  token kept its name for compatibility but now holds the coastal accent. `domainColor`
  reassigned off amber (Projects→indigo, Fitness→coral, Finance→sand). `ThemeMode`
  icons/labels updated (`sunset.fill`). Default theme set to `.light` (Beachside) in
  `KairoApp` + `SettingsView`. Stale "Golden Hour"/"gold" doc comments cleaned up.
- **Web:** `frontend/styles.css` (app) + `landing.css` retuned to ocean teal — all
  hardcoded amber `rgba(231,178,94,…)` glows swapped to teal `rgba(40,194,176,…)`.
- **App icon redesigned (coastal):** the gold half-moon ◐ became a **coastal sunset** —
  a coral→peach sun-disc on a deep-ocean gradient with a soft coral glow and the
  signature half-disc terminator (the Sunset hero distilled). Reproducible generator
  at `scripts/make_appicon.py` (Pillow, 4× supersample → 1024px, no alpha). Verified
  in the compiled bundle at home-screen size. Also added a matching `frontend/favicon.svg`
  (the web had none) linked from `index.html` + `landing.html`.
- **Verified:** iOS **build succeeded**; screenshots confirm all three themes —
  Beachside (sand + ocean teal, **zero amber**), Sunset (deep ocean + coral). The
  cfprefsd cache made external theme writes unreliable; a clean device **erase** was
  needed to screenshot the Beachside default.

## 2026-06-18 — Session 16: "Golden Hour" signature theme (3rd theme)

Added a third, brand-signature theme beyond light/dark.

- **Concept (product/design):** light = day, dark = night, neither captures
  *kairos* (the golden moment) + reflection. **Golden Hour** = a warm espresso
  world lit by a soft gold glow, parchment-cream text, luminous amber — journaling
  by lamplight at dusk. Distinct aesthetic, on-brand, emotionally aligned.
- **Implementation:** `ThemeMode` gained `.hero` (label "Golden Hour", `sun.haze.fill`,
  dark chrome). `Theme` rewritten from OS-trait-driven dynamic colors to **computed
  colors keyed on `Theme.mode`** (light/dark/hero), so a true 3rd theme works. Set in
  `RootView.init`; `KairoApp` rebuilds the tree via `.id(themeModeRaw)` on switch so
  all colors re-resolve. `kairoBackground()` adds a **warm radial glow** only in hero.
  Golden Hour palette is Kairō-original (espresso `#1A1208`, parchment `#F6E7CB`,
  luminous gold `#F5C061`).
- **Default:** Golden Hour is now the default first-launch theme (the "hero" look);
  Light/Dark/System remain in Settings.
- **Verified:** builds clean; **29 iOS tests pass**; screenshot confirms the warm
  espresso + gold-glow aesthetic, clearly distinct from light/dark.
- **Note:** also answered the repo's 6 domains (career/health/learning/relationships/
  money/decisions) — taxonomy change still deferred.

## 2026-06-18 — Session 15: inherit design system from Kairo-mvp repo

Aligned both surfaces to the canonical design in
`github.com/Narayan-Shanku/Kairo-mvp` (Next.js concept demo).

- **Fonts:** swapped Fraunces+Inter → **DM Serif Display + DM Sans** everywhere.
  iOS: fetched the TTFs, bundled them in `ios/Kairo/Fonts/`, registered via
  `UIAppFonts`, added `Theme.serif()/sans()` helpers and applied them (headings →
  DM Serif Display, base font → DM Sans). Web: swapped the Google Fonts link.
- **Palette:** adopted the repo's exact tokens — goldenrod **amber** (`#b8860b`
  light / `#d4a017` dark) + the bg/ink ramps. iOS `Theme` uses the full light+dark
  token set; **default theme is now light** (repo default). Web (`styles.css`,
  `landing.css`) uses the repo's dark tokens.
- **Brand + copy:** logo is now **"Kair·ō"** with the ō in amber; tagline →
  "your second memory"; landing eyebrow → "Your second memory · voice-first ·
  privately yours"; landing title → "Kairō — your second memory".
- **Texture:** paper-grain overlay added to the web (matches `.grain`).
- **Verified:** iOS builds clean with both fonts bundled; ran in Simulator —
  light theme + DM Serif Display + goldenrod amber confirmed. Web landing
  screenshot confirms the new type + palette + amber-ō logo.
- **Deliberately NOT changed:** our 7-domain taxonomy (Health/Career/Learning/
  Projects/Fitness/Finance/Relationships) vs the repo's 6 (career/health/learning/
  relationships/money/decisions) — that's a product decision, not visual design, and
  ours is wired through classification/cards/proactive. Flagged for a future call.

## 2026-06-18 — Session 14: submission assets (app icon + privacy policy)

- **App icon:** generated a 1024×1024 on-brand icon (warm-ink gradient + gold
  "kairos" half-moon ◐) by rendering an SVG with headless Chrome; placed at
  `ios/Kairo/Assets.xcassets/AppIcon.appiconset/` (single-size iOS icon, opaque/no
  alpha as Apple requires). `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` set in
  `project.yml`. Build compiles the asset catalog; **icon confirmed on the Simulator
  home screen.**
- **Privacy policy:** `docs/PRIVACY.md` + hostable `docs/privacy.html` — accurate to
  the standalone app (no accounts/servers/tracking/analytics; everything on-device;
  mic+Speech on-device; Apple App Privacy label = **Data Not Collected**). The HTML
  is what you host for the App Store privacy-policy URL.
- **Remaining for submission (account-gated, yours):** Apple Developer account →
  TestFlight build; fill the App Privacy label ("Data Not Collected"); set the
  privacy-policy URL to wherever you host `privacy.html`.

## 2026-06-18 — Session 13: fully standalone on-device iOS (no backend)

Made the iOS app run entirely on-device — no server, no network, no model
downloads — using iOS 26's built-in AI. The protocol-based MVVM paid off: only
new `Core/` implementations were needed; the UI/ViewModels were untouched.

- **Verified the linchpin first:** Apple **`FoundationModels`** (on-device LLM) is
  in the iOS 26.5 SDK; a minimal `GenerationService` compiled clean against it
  (`SystemLanguageModel.default.availability`, `LanguageModelSession().respond(to:)`).
- **On-device engine (`Core/`):** `EmbeddingService` (NLEmbedding, no download),
  `DomainClassifier` (keyword), `SM2` (Swift port), `OnDeviceStore` (JSON in
  Documents — memories+embeddings, cards w/ SM-2, prefs), `StreakCalc`, `DemoData`,
  `AppleSpeechTranscription` (SFSpeechRecognizer on-device, WhisperKit fallback).
- **Local repositories:** `LocalMemoryRepository` (capture→embed→store; query =
  cosine search → Foundation Models grounded answer, **extractive fallback** when
  the LLM is unavailable), `LocalCardRepository` (SM-2 + decision write-back),
  `LocalProactiveRepository` (streak/recall/nudges/digest, generated or templated).
- **Wiring:** `AppConfig.standalone = true` → `AppEnvironment.standalone()` swaps in
  the local repos. Backend-client wiring kept for `standalone=false`.
- **Verified:** build clean; **29 iOS tests** (7 new on-device engine tests — capture/
  search, query+sources, SM-2, decision write-back, proactive streak, demo seed).
  Then **stopped ALL backends** (compose down + no uvicorn) and launched the app —
  it rendered streak, 4 memories, a Day-3 recall card, review badge, recent list,
  with **zero server running**. Screenshot-confirmed.
- **Caveat:** Foundation Models generation requires Apple-Intelligence devices
  (iPhone 15 Pro+, iOS 26); other devices get extractive search. (Generation may
  even run in the Simulator on this Mac — the recall prompt looked generated.)

## 2026-06-18 — Session 12: containerized deploy (local, verified)

- **Sync server deployed** as a persistent, token-secured Docker container
  (`kairo-sync`, `:8787`, `restart=unless-stopped`, named volume) — verified
  health + 401/200 auth. The exact artifact for a cloud host.
- **Backend production image built + verified**: `docker build` → `kairo-backend`
  (1.61 GB); ran in a container reaching the host's Ollama via
  `host.docker.internal` → `/api/health` ok (models ✓) + web UI served.
- **Public cloud deploy NOT performed** — no flyctl/render/cloudflared installed
  and no account to auth as; that step is the user's (commands in `docs/DEPLOYMENT.md`).
- **Full stack run via `docker compose`** (`docker-compose.local.yml`, which reuses
  `~/.ollama` models + `~/.kairo` memories so it's fast + populated): all three
  containers up (backend :8000, ollama :11434, syncserver :8787); backend health ok
  with models, **20 real memories served**, a grounded RAG query ran
  backend-container → ollama-container correctly, and the web UI rendered. Stop with
  `docker compose -f docker-compose.local.yml down`; restart native with
  `uv run uvicorn backend.app:app --port 8000` + `ollama serve`.

## 2026-06-18 — Session 11: deploy hardening (token auth) + deploy configs

Made the backend + sync server **safe to expose**, and one-command deployable.

- **Token auth (opt-in):** `KAIRO_API_TOKEN` gates the backend's `/api/*`
  (`/api/health` exempt) via an HTTP middleware; `KAIRO_SYNC_TOKEN` gates the sync
  server's `/blob/*`. Unset → no auth, so local dev is unchanged.
- **Clients:** web `api()` attaches the bearer from localStorage and prompts once
  on 401; iOS `AppConfig.apiToken` + `KairoAPIClient.authorize`; sync client sends
  `KAIRO_SYNC_TOKEN`.
- **Deploy configs:** `syncserver/fly.toml` (Fly.io), `scripts/deploy-syncserver.sh`
  (Fly + token), `scripts/expose-backend.sh` (Cloudflare quick tunnel, warns if no
  token). `docs/DEPLOYMENT.md` updated with the secure-before-exposing flow.
- **Verified:** 2 new backend auth tests (TestClient) → **24 backend tests**; live
  curl over HTTP — backend health 200 / no-token 401 / correct-token 200, sync
  server health 200 / no-token 401 / authed reaches handler. iOS rebuilt, 23 tests pass.
- **Still the user's step:** running the actual `fly deploy` / tunnel (accounts,
  payment, exposing data) — all one command, documented.

## 2026-06-18 — Session 10: encrypted sync + deployment

The privacy moat — zero-knowledge cross-device sync — plus deployment prep.

- **`backend/sync/`:**
  - `crypto.py` — **Argon2id** (passphrase→256-bit key) + **AES-256-GCM**; versioned
    self-describing blob (`KAIRO1` + salt + nonce + ciphertext). Wrong passphrase /
    tampering fails loudly (GCM tag). `sync_id_for` = opaque passphrase-derived id.
  - `snapshot.py` — export/import the store (Chroma vectors+metadata + SQLite
    sessions/cards/digests/prefs); import is idempotent.
  - `client.py` — push (export→encrypt→PUT) / pull (GET→decrypt→import).
- **`syncserver/`** — standalone **zero-knowledge blob store** (FastAPI, no Kairō
  deps, no key, no plaintext; path-traversal-guarded ids). The only public-facing piece.
- **API:** `POST /api/sync/push`, `POST /api/sync/pull` (passphrase in, never stored).
- **Verified end-to-end:** device 1 pushed 3 memories → server blob is opaque
  ciphertext (`KAIRO1…`, no plaintext); a **fresh device 2 pulled + decrypted +
  restored all 3**; wrong passphrase can't locate the blob. 5 sync unit tests
  (crypto round-trip, wrong-key rejection, opaque-blob, snapshot) → **22 backend tests**.
- **Deployment:** `Dockerfile` (backend), `syncserver/Dockerfile`, `docker-compose.yml`
  (backend + ollama + syncserver), `docs/DEPLOYMENT.md`. **Sync-server Docker image
  built + run + health-checked** in a container. Actual cloud provisioning (Fly/Render/
  VPS, domain, payment) is the user's step — commands documented.
- **Pending:** iOS sync client (same Argon2id+AES-GCM in Swift — CryptoKit has AES-GCM,
  Argon2 needs an SPM package).

## 2026-06-18 — Session 9: Proactive Engine in the iOS app

Surfaced the Proactive Engine natively (consumes the Session-8 endpoints).

- **Models** (`Core/Models/Proactive.swift`): `Streak`, `RecallCard`, `Nudge`,
  `ProactiveToday`, `Digest`.
- **API/repo:** `KairoAPI`/`KairoAPIClient` gained `proactiveToday`, `respondRecall`,
  `dismissRecall`, `digest(refresh:)`; new `ProactiveRepository` (online-only,
  graceful-degrade); wired into `AppEnvironment`.
- **Home:** `HomeViewModel` loads `proactiveToday` (optional/`try?`); `HomeView` shows
  the **streak chip**, the **Day-3 recall card** (reply → `submitRecall` ingests a new
  memory, or **dismiss**), and **nudges**.
- **Digest:** new `Features/Digest/` (View + `@Observable` ViewModel) + a **Digest**
  tab in `RootView`; renders the digest's markdown via `AttributedString`, with a
  regenerate button.
- **Tests:** mock `ProactiveRepository` + HomeVM proactive tests + DigestVM tests →
  **23 iOS tests pass** (`xcodebuild test`).
- **Verified:** built, launched, screenshot-confirmed on iOS Home (8-day streak chip,
  the generated recall card, two nudges, the new Digest tab).

## 2026-06-18 — Session 8: Proactive Engine

Built the retention layer (Technical Architecture §4) — Kairō now reaches out
instead of waiting to be searched.

- **`backend/proactive/`:**
  - `streaks.py` — check-in streak (current/longest) computed on-demand from
    distinct `sessions` dates (works with any data, incl. the demo set).
  - `recall.py` — **Day-3 recall**: surfaces the most specific unsurfaced memory
    from the 2–5-day window with an LLM-generated warm follow-up; cached per day in
    `user_preferences`; responding ingests a new memory; dismiss/respond suppress resurface.
  - `digest.py` — **weekly digest**: groups last 7 days by domain → LLM reflection
    (themes, cross-domain patterns, open questions); cached in the `digests` table.
  - `nudges.py` — **smart nudges**: streak-risk + recurring-domain patterns (heuristic,
    no LLM, so the endpoint stays fast).
- **API:** `GET /api/proactive/today` (streak + recall + nudges), `POST /api/proactive/respond`,
  `POST /api/proactive/dismiss`, `GET /api/digest?refresh=`. DB helpers for digests added.
- **Web app:** Home now shows the streak chip, the Day-3 recall card (reply → new
  memory, or dismiss), and nudges; new **Digest** tab (with regenerate).
- **Verified:** live — 8-day streak, a generated recall ("A few days ago you mentioned
  feeling off — how's your stomach and sleep been since then?"), 3 nudges, and a
  domain-grouped weekly digest from 13 memories. Screenshot-confirmed on Home.
- **Tests:** `tests/test_proactive.py` (streak/nudges/recall-candidate pure; digest
  Ollama-guarded) → **17 backend tests pass**.

## 2026-06-18 — Session 7: theme toggle + offline (cache + on-device search)

- **Dark / Light / System theme toggle:** made `Theme` colors adaptive (dynamic
  `UIColor` per `userInterfaceStyle`) so the whole app flips with no view changes;
  added `ThemeMode` + a **Settings** sheet (gear on Home) with a picker, persisted
  via `@AppStorage("themeMode")` and applied with `.preferredColorScheme`. Both
  modes screenshot-verified.
- **Offline cache:** repositories now write-through to an on-device cache and read
  from it (plus derive Stats) when the backend is unreachable. **Verified offline:**
  killed the backend, relaunched → Home shows cached memories + derived 6/6/5 stats,
  no error.
  - ⚠️ Implementation note: started with **SwiftData**, but it `SIGTRAP`'d on basic
    `ModelContext` fetch/insert/save on the main thread in Xcode 26.5 — even with
    bare `@Model` classes and a fresh store, no diagnosable message. Pivoted to a
    **JSON file cache** (`LocalCache` → Caches dir; `Memory`/`Card` are `Codable`).
    Simpler, crash-free, right tool for a small key-less blob cache. Same `LocalCache`
    API, so repositories were unchanged.
- **On-device retrieval:** `OnDeviceSearch` ranks cached memories by cosine
  similarity using Apple's built-in **`NLEmbedding`** (no model download).
  `Ask` falls back to it when the backend query fails → "You're offline — here are
  related memories." (On-device *generation* still needs the server / a future MLX LLM.)
- **Tests:** +5 (OnDeviceSearch + Ask offline fallback) → **18 iOS tests, all pass**.
  Note: under unit tests the host app skips `AppEnvironment.live()` (see `KairoApp.isTesting`)
  so the runner bootstraps cleanly.

## 2026-06-17 — Session 6: iOS Phase 2 — MVVM refactor + on-device WhisperKit

Re-architected the iOS app to production MVVM and added on-device transcription.

- **Backend:** added `POST /api/transcribe` (transcribe-only, no ingest) so
  transcription is a swappable client concern.
- **MVVM refactor** (feature-based): restructured `ios/Kairo/` into
  `App/` (KairoApp, RootView, **AppEnvironment** DI container),
  `Features/{Home,Capture,Ask,Review}/` (each a View + `@Observable` ViewModel),
  `Core/{Models,Services,Repositories,Utils,Views/Reusable}/`, `Config/`.
  - ViewModels depend on **protocols** (`MemoryRepository`, `CardRepository`,
    `TranscriptionService`, `AudioRecording`) → unit-testable; views are pure UI.
  - `KairoAPI` protocol + `KairoAPIClient`; repositories wrap it (seam for a future
    SwiftData cache). DI via `@Environment(AppEnvironment.self)`.
- **On-device transcription:** added WhisperKit SPM package (resolved 0.18.0 +
  swift-transformers etc.). `WhisperKitTranscription` loads the `base` model lazily
  and transcribes locally, **falling back to the `/api/transcribe` endpoint** if the
  model/network isn't ready. Capture flow is now transcribe → ingest-as-text, so
  the on-device swap is invisible to the feature. Toggle: `AppConfig.useOnDeviceTranscription`.
- **Unit tests:** `KairoTests/` with mock repos/services (Swift Testing) — 13 tests
  across all four ViewModels. **All pass** via `xcodebuild test`.
- **Bugs caught by running it (not just compiling):**
  1. `ReviewView` caught-`error` shadowed `@State error` → `self.error`.
  2. `URL.appendingPathComponent` percent-encoded "?", breaking query-string
     endpoints (stats worked, `memories?limit=` 404'd) → added `makeURL` that
     composes the raw absolute string.
- **Verified:** builds for iPhone 17 simulator, runs at full parity (stats, review
  badge, recent memories), WhisperKit links + app launches healthy. iOS 18+ target.

## 2026-06-17 — Session 5: iOS app (native SwiftUI MVP scaffold)

Started the iPhone app — chosen approach: **native SwiftUI thin client** to the
existing FastAPI backend (Option A; on-device ML is Phase 2). Decided after
discussing architecture + cost (`docs/MOBILE_ARCHITECTURE.md`).

- **`ios/` project** (XcodeGen-generated `Kairo.xcodeproj`):
  - `KairoApp`, `Config` (backend base URL), `Theme` (kairos-gold palette + hex/date helpers).
  - `Models.swift` — Codable mirrors of the backend JSON.
  - `APIClient.swift` — async URLSession client (stats, memories, capture text,
    query, cards due/review/pin, card stats, demo seed, **multipart voice upload**).
  - `AudioRecorder.swift` — AVFoundation recording → `.m4a` → upload.
  - `Views/` — `RootView` (tab bar) + Home (stats, review badge, recent, demo seed),
    Capture (voice + text), Ask (chat, citations, ⭐ Remember this), Review (flashcards
    with the decision-reflection loop). Shared `Components.swift`.
  - `project.yml` (XcodeGen), Info.plist generated with `NSMicrophoneUsageDescription`
    + `NSAllowsLocalNetworking`.
- **Tooling:** `brew install xcodegen` → `xcodegen generate` produced the project.
- **Docs:** added `docs/MOBILE_ARCHITECTURE.md` (layer mapping, the LLM-placement
  decision, recommended Option-C architecture, MVP cost map, phasing).
- **BUILT & RAN (after Xcode 26.5 installed):** `xcodebuild` for the iPhone 17
  simulator → **BUILD SUCCEEDED**; app installed + launched and rendered live data
  from the backend (stats, review badge, recent memories). Two fixes were needed:
  1. `ReviewView.load()` — caught `error` shadowed `@State error`; qualified as `self.error`.
  2. CodeSign failed with "resource fork / detritus not allowed" (Desktop xattrs);
     fixed by `xattr -cr` on the project + building the simulator target with
     `CODE_SIGNING_ALLOWED=NO` (simulator needs no signing). Both noted in `ios/README.md`.

## 2026-06-17 — Session 4: Memory Review (spaced-repetition flashcards)

Shipped the **Review** layer — Kairō writes its ROM back into your biological RAM,
and it's the first concrete piece of the Proactive Engine (the retention engine).

- **New module `backend/review/`:**
  - `scheduler.py` — pure SM-2 (Again/Hard/Good/Easy → q 2/3/4/5; lapse resets +
    interval 1; ease floor 1.3). New cards due immediately.
  - `cards.py` — LLM card generation (`generate_from_memory`, quality-gated:
    insight | decision | none, confidence ≥ 0.6), `pin_memory` / `pin_qa`, `due`,
    `review` (SM-2 reschedule + **validation loop**: decision cards write the
    reflection back as a new memory via `pipeline.ingest_text`), `stats` (due /
    total / reviewed_today / streak).
- **Storage:** `cards` + `card_reviews` tables and helpers added to
  `backend/storage/db.py` (+ `idx_cards_due`).
- **Capture hook:** `backend/pipeline.py` best-effort distills a card on every
  text/voice capture (errors swallowed so capture never fails).
- **API:** `GET /api/cards/due`, `GET /api/cards/stats`, `GET /api/cards`,
  `POST /api/cards/{id}/review`, `POST /api/cards/pin`, `POST /api/cards/generate`.
- **Demo:** `backend/demo.py` seeds 5 pre-made cards (instant Review tab).
- **Frontend:** new **Review** tab + flashcard flow (front → reveal answer + the
  decision reflection field → Again/Hard/Good/Easy), Home "🔁 N to review" badge
  with streak, and a "⭐ Remember this" button on Ask answers (`frontend/*`).
- **Tests:** `tests/test_review.py` — SM-2 + card CRUD/review (no Ollama) + the
  validation loop (Ollama-gated). **13/13 passing.**
- **Verified live:** auto-gen distilled 11 cards from 13 memories (2 mundane ones
  correctly skipped); decision-card reflection created a new memory (14→15);
  capture quality gate: insight entry → card, "had a coffee, it was fine" → no card.

## 2026-06-17 — Session 3: MCP context layer + strategy docs

**Built the first brick of the "$50B context layer" thesis** (Kairō feeds every AI
agent instead of competing with their memory).

- **MCP memory server** (`backend/mcp_server.py`) using the MCP Python SDK / FastMCP.
  Exposes 5 tools over stdio: `search_memory`, `ask_memory`, `add_memory`,
  `recent_memories`, `memory_stats` — all wrapping the existing engine and reading
  the same `~/.kairo` store as the web app.
  - Verified end-to-end with a real MCP client (subprocess + stdio handshake +
    `initialize` + `list_tools` + `call_tool`). Any MCP client (Claude Code/Desktop,
    agents) can now read **and write** the user's memory.
  - Registration into an AI client's config is a one-time **manual** step
    (`docs/MCP_SETUP.md`) — agents are blocked from editing their own MCP config.
- **Strategy docs:**
  - `docs/INVESTOR_NARRATIVE.md` — one-page investor narrative (context-layer thesis,
    GTM wedge→layer→capture, $50B math, the ask).
  - `docs/MCP_SETUP.md` — how to connect Kairō to Claude Code / Claude Desktop.
- Added `mcp>=1.2.0` dependency.
- Started this `BUILD_LOG.md`.

## 2026-06-17 — Session 2: Product design pass (traction)

Took full ownership of product design; redesigned for credibility/traction.

- **Premium landing page** at `/` (`frontend/landing.{html,css,js}`) — warm dark
  editorial theme, Fraunces + Inter type pairing, "kairos gold" accent, scroll-reveal
  animations, product mock, Day-3 + health-intelligence sections, privacy pillar,
  pricing, CTA. The app moved to `/app`.
- **App restyle** (`frontend/index.html`, `styles.css`, `app.js`) to match — polished
  empty states, Ask suggestion chips, micro-interactions.
- **Demo seeding** (`backend/demo.py`, `POST /api/demo/seed`, "Load demo memories"
  button) — 13 realistic backdated memories across all 7 domains so the app isn't empty.
- **Retrieval quality fix (important):** BM25 was ranking irrelevant memories top for
  natural-language questions because it matched stopwords like "my". Added stopword
  removal + a light suffix stemmer (`bloating`/`bloated` → `bloat`) in
  `backend/retrieval/search.py`; trimmed citations to results ≥0.6× the top score in
  `rag.py`. Bloating query now correctly cites only the relevant Health memories.
- Note: the React-only tools from the `website-builder-setup` skill (Framer Motion,
  21st.dev, uipro-cli) don't fit this vanilla-JS/Python stack; design was done by hand.

## 2026-06-17 — Session 1: Milestone 1 — core memory engine

Greenfield → working product. Built the 4-layer pipeline from the design docs.

- **Scaffold:** `pyproject.toml` (uv), `config.py` (`~/.kairo` layout), package structure.
- **Capture** (`backend/capture/`): `voice.py` (faster-whisper, ffmpeg decode),
  `text.py` (normalize).
- **Structure** (`backend/structure/`): `chunker.py` (sentence-aware sliding window),
  `embedder.py` (Ollama `nomic-embed-text`, doc/query prefixes, L2-norm),
  `classifier.py` (7-domain multi-label + tone via LLM JSON + keyword pre-tag),
  `enricher.py` (metadata).
- **Storage** (`backend/storage/`): `vectors.py` (ChromaDB, cosine),
  `db.py` (SQLite: sessions, prefs; reserved tables for M2), `files.py` (raw audio).
- **Retrieval** (`backend/retrieval/`): `search.py` (hybrid semantic + BM25 → RRF),
  `rerank.py` (domain boost, recency decay, session diversity), `rag.py` (grounded,
  cited generation with Ollama `llama3.1:8b`).
- **Pipeline** (`backend/pipeline.py`): orchestrates Capture → Structure → Storage.
- **API + frontend** (`backend/app.py`, `frontend/`): capture/query/search/memories/
  stats/health endpoints; Home/Record/Ask/Timeline/Insights views.
- **Tests** (`tests/`): chunker units + full RAG pipeline (5 passing).
- Verified end-to-end: text + voice capture, and *"What triggers my bloating?"* →
  grounded answer citing the user's own memories by date.

> Substitutions from the design doc's spec (kept deliberately): Ollama
> `nomic-embed-text` instead of ONNX BGE; LLM-based classification instead of
> distilbart-mnli — to avoid a torch dependency. Interfaces unchanged, so swapping
> back later is a drop-in.

---

## Next up (proposed)

1. **Proactive Engine (Milestone 2):** spaced-repetition Review ✅ done; still to do —
   Day-3 recall, weekly digest, review notifications/nudges. SQLite schema already
   stubs `streaks`/`digests`/`proactive_queue`. FSRS as a Review upgrade.
2. **Memory protocol hardening:** scoping/permissions on MCP tools, write-attribution
   (which agent wrote what), and a hosted/remote MCP option.
3. **Proactive cross-domain insights** (health correlations, decision pre-mortems) to
   drive daily-active value and retention.
4. **Reposition the wedge:** hero promise *"Your AI finally remembers you — everywhere."*

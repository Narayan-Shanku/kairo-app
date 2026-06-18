# Kairō — iOS app (MVP)

A native **SwiftUI** iPhone app for Kairō, built **MVVM** (iOS 18+). Retrieval and
storage run on the Kairō FastAPI backend; **transcription runs on-device** via
WhisperKit (falling back to the server when the model isn't ready). See
`../docs/MOBILE_ARCHITECTURE.md` for the full architecture.

> ✅ **Verified building, running, and unit-tested** in the iOS Simulator
> (Xcode 26.5, iPhone 17): launches, pulls live backend data, WhisperKit links, and
> all 13 ViewModel tests pass via `xcodebuild test`.

## What you need

- **Full Xcode** (free, ~7 GB, Mac App Store). The Command Line Tools alone aren't enough.
- The **Kairō backend running** (from the repo root):
  ```bash
  uv run uvicorn backend.app:app --reload --port 8000
  ```
- For running on a **physical iPhone**: a free Apple ID works for 7-day builds;
  the **Apple Developer Program ($99/yr)** is needed for TestFlight / long-lived installs.

## Open & run

The Xcode project is already generated (`Kairo.xcodeproj`). If you change
`project.yml`, regenerate it:

```bash
brew install xcodegen   # one time
cd ios && xcodegen generate
```

Then:

1. `open ios/Kairo.xcodeproj`
2. Pick an **iPhone Simulator** (e.g. iPhone 17) as the run target.
3. Press **⌘R**. The Simulator shares this Mac's network, so the default
   `baseURL` (`http://localhost:8000` in `Kairo/Config.swift`) just works.

### Or build & run from the command line (no GUI)

```bash
cd ios
xattr -cr Kairo Kairo.xcodeproj            # strip Desktop xattrs (avoids a codesign error)
xcodebuild -project Kairo.xcodeproj -scheme Kairo \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcrun simctl boot "iPhone 17" 2>/dev/null; open -a Simulator
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Kairo.app
xcrun simctl launch booted com.kairo.app
```

> Note: the `xattr -cr` + `CODE_SIGNING_ALLOWED=NO` combo is only needed because
> files on the Desktop carry extended attributes that break ad-hoc codesigning;
> the Simulator doesn't require signing. In the Xcode GUI, ⌘R handles this fine.

### Running on your real iPhone

1. In Xcode → target **Kairo** → *Signing & Capabilities* → select your Team
   (your Apple ID) and a unique bundle id.
2. In `Kairo/Config.swift`, set `baseURL` to your Mac's LAN address:
   ```bash
   ipconfig getifaddr en0      # e.g. 192.168.1.42  →  http://192.168.1.42:8000
   ```
   Phone and Mac must be on the same Wi-Fi. (HTTP to the LAN is allowed via the
   `NSAllowsLocalNetworking` key already set in `project.yml`.)
3. Plug in the phone, select it as the run target, **⌘R**.

## Architecture (MVVM, feature-based)

```
Kairo/
  App/         KairoApp · RootView · AppEnvironment (DI container)
  Config/      AppConfig (base URL, on-device toggle)
  Features/    Home · Capture · Ask · Review · Digest · Settings  (View + @Observable ViewModel)
  Core/
    Models/        Memory · Card · Stats · RAGResponse · CaptureSummary · ThemeMode · Proactive
    Services/      KairoAPI(+Client) · AudioRecording · TranscriptionService
                   (RemoteTranscription · WhisperKitTranscription) · OnDeviceSearch
    Repositories/  MemoryRepository · CardRepository · ProactiveRepository  (cache-backed where useful)
    Storage/       LocalCache (JSON file cache)
    Utils/         Theme (adaptive light/dark) · Extensions
    Views/Reusable/ DomainTag · MemoryRow · GoldButton
KairoTests/    Mock repos/services + 23 ViewModel/search tests (Swift Testing)
```

- **Proactive Engine** on Home: streak chip, Day-3 recall card (reply → new memory,
  or dismiss), nudges; plus a **Digest** tab (weekly AI reflection).

- **Light / Dark / System** theme — Settings (gear on Home), persisted via `@AppStorage`.
- **Offline:** repositories cache to `LocalCache` (JSON) and read from it when the
  backend is down; `Ask` falls back to **on-device search** (`NLEmbedding`) over the
  cache. _(On-device generation still needs the server — a future MLX LLM spike.)_

- **ViewModels are `@Observable`** and depend only on **protocols**, so they're
  unit-tested with mocks (no network). Views are pure UI.
- **Dependency injection** via `AppEnvironment` (`@Environment(AppEnvironment.self)`).
- **On-device transcription:** `WhisperKitTranscription` (WhisperKit SPM) loads
  Whisper locally on first use and transcribes on-device, falling back to the
  backend `/api/transcribe` if needed. Toggle in `Config/AppConfig.swift`.

## Run the tests

```bash
cd ios
xcodebuild test -project Kairo.xcodeproj -scheme Kairo \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

## Roadmap (remaining Phase 2 → privacy-grade)

On-device **generation** (MLX LLM) so grounded answers work fully offline, higher-
quality on-device embeddings (Core ML BGE), CloudKit E2E sync, and APNs review
nudges. Full plan in `../docs/MOBILE_ARCHITECTURE.md`.

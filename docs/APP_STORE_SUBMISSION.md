# Kairō — App Store / TestFlight Submission Guide

A start-to-finish checklist to get Kairō onto TestFlight and the App Store, with
draft metadata you can paste into App Store Connect. The icon and privacy policy
are already done; the main gate is the **paid Apple Developer account**.

---

## 0. Prerequisites

- [ ] **Apple Developer Program membership** ($99/yr) — required for TestFlight,
      the App Store, App Groups (the widget), and removing the 7-day sideload expiry.
- [ ] Full **Xcode** installed and signed into the developer account
      (Xcode → Settings → Accounts).
- [ ] Decide the **bundle identifier**. `com.kairo.app` is taken by another team;
      this project uses **`com.kairomemory.kairo`** (widget: `com.kairomemory.kairo.widget`).
      You may register a cleaner one you own under your paid team and update
      `ios/project.yml` (`PRODUCT_BUNDLE_IDENTIFIER` + the App Group).

---

## 1. App Store Connect — create the app record

1. [ ] **Certificates, Identifiers & Profiles** → register the App ID
       `com.kairomemory.kairo` with **App Groups** capability, and the App Group
       `group.com.kairomemory.kairo`. Register the widget App ID too.
2. [ ] **App Store Connect → Apps → "+" → New App**
   - Platform: iOS
   - Name: **Kairō** (must be globally unique on the App Store — have a backup like
     "Kairō — Second Memory" ready in case "Kairō" is taken)
   - Primary language: English (U.S.)
   - Bundle ID: `com.kairomemory.kairo`
   - SKU: `kairo-ios-001`

---

## 2. Metadata (draft — paste & tweak)

**Name (30 chars):** `Kairō`

**Subtitle (30 chars):** `Your second memory`

**Promotional text (170 chars):**
> Speak your day. Ask your life. Kairō turns your check-ins into a private memory
> you can actually think with — answers grounded in your own words, all on your iPhone.

**Description:**
> Kairō is your second memory — a voice-first personal AI that remembers everything
> you tell it and lets you ask questions about your own life.
>
> Speak or type a short check-in. Kairō understands it, organizes it by life area,
> and keeps it. Later, just ask — "What helps my sleep?", "What did I decide about
> the job?", "How's my training going?" — and get a clear answer grounded in your
> own past words, with the dates it came from. If it doesn't know, it says so. It
> never makes things up.
>
> Private by design: your memories are stored only on your iPhone — no account, no
> sign-in, no tracking. On iPhones with Apple Intelligence, answers are generated
> entirely on-device. On other iPhones, only the few snippets needed to answer a
> question are sent to a private answer service — and you can turn that off in
> Settings to stay fully on-device.
>
> • Capture by voice or text, transcribed on-device
> • Ask anything and get cited answers from your own history
> • Review — turn your insights into flashcards that resurface so they stick
> • Streaks & a friendly sun mascot that keeps you checking in
> • A home-screen widget and gentle daily reminders
> • Beautiful coastal themes: Beachside, Deep Ocean, and Sunset
>
> Private by design. On-device by default. Your life, remembered.

**Keywords (100 chars):**
`memory,journal,voice,AI,diary,notes,private,second brain,recall,reflection,streak,mindfulness`

**Category:** Primary **Productivity** · Secondary **Lifestyle**
(Health & Fitness is a viable alternative primary given the reflection/journaling angle.)

**Copyright:** `© 2026 Achyuth Narayan Shanku`

**Support URL / Marketing URL:** a simple page or the GitHub repo for now.

---

## 3. App Privacy ("nutrition label")

The shipped build sends retrieved snippets + the question to the cloud answer
service on non-Apple-Intelligence devices, so **"Data Not Collected" is no longer
accurate**. Answer in App Store Connect → App Privacy:

- [ ] **Data collection: Yes** → declare **User Content → Other User Content**
      - Used for: **App Functionality** only
      - Linked to identity: **No** (no accounts, no user identifiers are sent)
      - Used for tracking: **No**
- [ ] Everything else (contact info, identifiers, location, usage data,
      diagnostics…): **not collected**.
- [ ] **Privacy policy URL** (required): host `docs/privacy.html`
      (GitHub Pages, Netlify, or any static host) and paste the URL. The policy
      already discloses the cloud answer path, Cloudflare + Anthropic as
      processors, and the Settings opt-out.
- [ ] If you later enable encrypted sync, add the encrypted blob upload
      (still zero-knowledge — the server can't read it).

---

## 4. Age rating, pricing, availability

- [ ] **Age rating:** 4+ (no objectionable content).
- [ ] **Pricing:** Free (recommended for v1) — set tier in App Store Connect.
- [ ] **Availability:** all territories (or start with yours).

---

## 5. Screenshots (required)

Apple requires **6.9-inch** iPhone screenshots (1320 × 2868 px). 3–5 are enough.

**✅ Ready to upload:** six spec-size captures live in `docs/screenshots/appstore/`
(taken on an iPhone 17 Pro Max simulator, 9:41 status bar, demo data, real
generated answers):

1. `01-home` — streak mascot + check-in CTA + Day-3 recall card + nudges
2. `02-ask` — a generated answer with date citations
3. `03-review` — a revealed flashcard with the rating row
4. `04-digest` — the generated weekly reflection
5. `05-settings` — themes, reminders, and the widget previews
6. `06-home-sunset` — Home in the signature Sunset theme, sun beaming

**To regenerate** (e.g. after UI changes) run the screenshot harness:
```bash
cd ios && xcodegen generate
xcrun simctl erase "iPhone 17 Pro Max" && xcrun simctl boot "iPhone 17 Pro Max"
xcrun simctl status_bar "iPhone 17 Pro Max" override --time "9:41" \
  --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100
xcodebuild test -project Kairo.xcodeproj -scheme KairoScreenshots \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -resultBundlePath build/screens.xcresult CODE_SIGNING_ALLOWED=NO
xcrun xcresulttool export attachments --path build/screens.xcresult \
  --output-path ../docs/screenshots/appstore
```
(The harness drives the cloud answer path, so the proxy must be configured.
Optional: add framed/marketing versions; plain device screenshots are accepted.)

- [ ] App icon: ✅ already in `ios/Kairo/Assets.xcassets/AppIcon.appiconset` (1024×1024, no alpha).

---

## 6. Build settings to confirm before archiving

- [ ] In `ios/project.yml`, set your `DEVELOPMENT_TEAM` (or pick the team in Xcode).
- [x] **`ITSAppUsesNonExemptEncryption = false`** — already set in `ios/project.yml`
      (Kairō uses only standard/exempt encryption), so the export-compliance prompt
      is skipped on every upload.
- [ ] **Cloud answers config:** confirm `AppConfig.cloudGenerationURL` and
      `cloudGenerationToken` hold the real proxy values in your **local** tree at
      archive time (they are committed as `nil` placeholders — the real values live
      only as a local uncommitted diff). Archiving from a fresh clone would silently
      ship with cloud answers off.
- [ ] Bump `MARKETING_VERSION` (e.g. `1.0.0`) and `CURRENT_PROJECT_VERSION` per upload.
- [ ] Confirm the App Group entitlement is present on **both** the app and widget targets.

---

## 7. Archive & upload

**Xcode (simplest):**
1. Select **Any iOS Device (arm64)** as the destination.
2. **Product → Archive.**
3. In the Organizer: **Distribute App → App Store Connect → Upload.**

**Command line (alternative):**
```bash
cd ios && xcodegen generate
xcodebuild -project Kairo.xcodeproj -scheme Kairo \
  -configuration Release -archivePath build/Kairo.xcarchive \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/Kairo.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export \
  -allowProvisioningUpdates
# then upload build/export/*.ipa via Transporter.app or `xcrun altool`/`notarytool`
```

---

## 8. TestFlight (do this first)

- [ ] After the build processes, enable **TestFlight** internal testing.
- [ ] Add yourself / testers; install via the TestFlight app (no cable, no 7-day expiry).
- [ ] Smoke-test on a real device: capture → ask → review → widget → reminder.

---

## 9. App Review notes (paste into "Notes for Review")

> Kairō requires no login, account, or credentials. To test:
> 1. On first launch, load the demo data (or capture a check-in by voice/text).
> 2. Open **Ask** and ask a question (e.g. "what triggers my bloating?"); the
>    answer is grounded in the stored memories and cites their dates.
> 3. Answer generation runs on-device via Apple Intelligence (Foundation Models)
>    on supported devices. On devices without Apple Intelligence, the app sends
>    only the few retrieved memory snippets + the question over HTTPS to our
>    stateless answer service (disclosed in the privacy policy; declared as
>    User Content / App Functionality / Not Linked). This can be disabled in
>    Settings → "Use private cloud for answers", after which the app is fully
>    on-device and Ask returns the most relevant memories instead.
> All other features (capture, transcription, search, review, streaks, widget)
> are fully on-device.

---

## 10. Final pre-submit checklist

- [ ] Paid account active · App ID + App Group registered
- [ ] Metadata, keywords, category, privacy policy URL set
- [ ] App Privacy = User Content (App Functionality, Not Linked, No Tracking)
- [ ] Privacy policy (hosted) matches the shipped cloud-answers behavior
- [ ] 6.9" screenshots uploaded · icon present
- [x] `ITSAppUsesNonExemptEncryption = false` (in project.yml)
- [ ] Real proxy URL + token present in the local tree at archive time
- [ ] Proxy live-checked (`curl` smoke test) + `DAILY_CAP` set to a value you're
      comfortable paying for at public scale
- [ ] Release build archived & uploaded · TestFlight smoke-tested on BOTH an
      Apple-Intelligence device and a non-AI device/Simulator (cloud path)
- [ ] Submit for Review 🚀

---

## Known gotchas

- **Bundle ID uniqueness** — `com.kairo.app` is already registered to another team
  (globally unique). This project uses `com.kairomemory.kairo`.
- **App Groups need the paid account** — the widget's app↔widget data bridge won't
  provision on a free team. Local notifications (reminders) do **not** need it.
- **Foundation Models** — only on Apple-Intelligence devices/iOS 26+. The code already
  guards with `#available` and degrades gracefully (cloud answers → extractive); call
  this out in review notes so it isn't flagged as "feature not working."
- **Cloud answers at public scale** — the proxy is a personal Cloudflare Worker on
  your own Anthropic key. The `DAILY_CAP` (proxy/wrangler.toml) is the global cost
  ceiling shared by ALL users; size it deliberately before launch, and remember you
  can rotate `SHARED_TOKEN` + redeploy in about a minute if it's ever abused.
- **Reviewers likely test on non-AI hardware** — App Review may exercise the cloud
  path, so the App Privacy label and policy MUST be accurate before submitting;
  "Data Not Collected" with observable network calls is a rejection (Guideline 5.1.1/5.1.2).

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
> Everything runs on your iPhone. Your memories never leave your device — no account,
> no cloud, no tracking.
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

Kairō is on-device, so this is short — answer in App Store Connect → App Privacy:

- [ ] **Data collection:** *Data Not Collected.* (The standalone app stores everything
      locally and sends nothing to a server.)
- [ ] **Privacy policy URL** (required): host `docs/privacy.html`
      (GitHub Pages, Netlify, or any static host) and paste the URL.
- [ ] If you later enable encrypted sync, update this to disclose the encrypted blob
      upload (still zero-knowledge — the server can't read it).

---

## 4. Age rating, pricing, availability

- [ ] **Age rating:** 4+ (no objectionable content).
- [ ] **Pricing:** Free (recommended for v1) — set tier in App Store Connect.
- [ ] **Availability:** all territories (or start with yours).

---

## 5. Screenshots (required)

Apple requires **6.9-inch** iPhone screenshots (1320 × 2868 px). 3–5 are enough.
Suggested set (we already have coastal captures in `docs/screenshots/`):

1. Home with the streak mascot + check-in
2. Ask → a cited answer
3. Review (a flashcard)
4. The home-screen widget
5. Themes (Beachside / Deep Ocean / Sunset)

Capture clean ones from a 6.9" simulator:
```bash
xcrun simctl boot "iPhone 16 Pro Max"        # a 6.9" device
xcrun simctl io "iPhone 16 Pro Max" screenshot shot1.png
```
(Optional: add framed/marketing versions; plain device screenshots are accepted.)

- [ ] App icon: ✅ already in `ios/Kairo/Assets.xcassets/AppIcon.appiconset` (1024×1024, no alpha).

---

## 6. Build settings to confirm before archiving

- [ ] In `ios/project.yml`, set your `DEVELOPMENT_TEAM` (or pick the team in Xcode).
- [ ] Add **`ITSAppUsesNonExemptEncryption = false`** to the app's Info.plist
      (Kairō uses only standard/exempt encryption) so you skip the export-compliance
      prompt on every upload.
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

> Kairō runs entirely on-device — no login or server. To test:
> 1. On first launch, load the demo data (or capture a check-in by voice/text).
> 2. Open **Ask** and ask a question; the answer is generated on-device and cites
>    the source memories.
> 3. On-device answer generation uses Apple Intelligence (Foundation Models) and
>    requires a supported device with Apple Intelligence enabled
>    (Settings → Apple Intelligence & Siri). On unsupported devices the app still
>    works; answers fall back to extractive results.
> No account or credentials are required.

---

## 10. Final pre-submit checklist

- [ ] Paid account active · App ID + App Group registered
- [ ] Metadata, keywords, category, privacy policy URL set
- [ ] App Privacy = Data Not Collected
- [ ] 6.9" screenshots uploaded · icon present
- [ ] `ITSAppUsesNonExemptEncryption = false`
- [ ] Release build archived & uploaded · TestFlight smoke-tested
- [ ] Submit for Review 🚀

---

## Known gotchas

- **Bundle ID uniqueness** — `com.kairo.app` is already registered to another team
  (globally unique). This project uses `com.kairomemory.kairo`.
- **App Groups need the paid account** — the widget's app↔widget data bridge won't
  provision on a free team. Local notifications (reminders) do **not** need it.
- **Foundation Models** — only on Apple-Intelligence devices/iOS 26+. The code already
  guards with `#available` and degrades gracefully; call this out in review notes so
  it isn't flagged as "feature not working."

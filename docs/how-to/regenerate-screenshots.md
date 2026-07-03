# How to regenerate the App Store screenshots

Regenerate the six 6.9-inch App Store screenshots in `docs/screenshots/appstore/`
after a UI change. This is the detailed version of
[App Store Submission Guide §5](../APP_STORE_SUBMISSION.md); keep the two in sync.

## Prerequisites

- Xcode with an **iPhone 17 Pro Max** simulator (6.9", iOS 18+). Check with
  `xcrun simctl list devices`.
- `xcodegen` installed (`brew install xcodegen`).
- **Cloud generation configured locally.** The Simulator has no Apple Foundation
  Models, so the harness exercises the cloud answer path. In your local tree,
  `ios/Kairo/Config/AppConfig.swift` must have real values for
  `cloudGenerationURL` (`<your-proxy-url>`) and `cloudGenerationToken`
  (`<token>`). These are committed as `nil` placeholders — the real values live
  only as a local, uncommitted diff. On a fresh clone the run will time out at
  the Ask step.
- Budget: one run sends roughly ten generation requests, which count against the
  proxy's daily cap.

All commands below run from the repo's `ios/` directory unless noted.

## Steps

1. **Regenerate the Xcode project.**

   ```bash
   cd ios && xcodegen generate
   ```

   Expected: `⚙️  Generating project...` then `Created project at .../Kairo.xcodeproj`.

2. **Erase and boot the simulator.** The simulator **must** be erased: the
   harness asserts that the fresh-install "Load demo memories" seed banner is
   showing, and it only appears on a clean install.

   ```bash
   xcrun simctl erase "iPhone 17 Pro Max"
   xcrun simctl boot "iPhone 17 Pro Max"
   ```

   Expected: both commands exit silently. (`erase` fails if the device is
   booted — shut it down first with `xcrun simctl shutdown "iPhone 17 Pro Max"`.)

3. **Override the status bar** to the standard marketing look (9:41, full
   battery, full signal).

   ```bash
   xcrun simctl status_bar "iPhone 17 Pro Max" override --time "9:41" \
     --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100
   ```

   Expected: exits silently; the booted simulator's clock reads 9:41.

4. **Run the screenshot harness** (the `KairoScreenshots` scheme runs
   `KairoUITests/ScreenshotTests.swift`; it is deliberately kept out of the main
   `Kairo` test scheme so normal `xcodebuild test` runs stay fast and offline).

   ```bash
   xcodebuild test -project Kairo.xcodeproj -scheme KairoScreenshots \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
     -resultBundlePath build/screens.xcresult CODE_SIGNING_ALLOWED=NO
   ```

   Expected: several minutes (the Ask answer waits up to 90 s, the Digest up to
   120 s), ending in `** TEST SUCCEEDED **`. Delete any stale
   `build/screens.xcresult` first — `xcodebuild` refuses to overwrite it.

5. **Export and rename the captures.** The attachments export with generated
   file names; `manifest.json` maps them back to the attachment names.

   ```bash
   xcrun xcresulttool export attachments --path build/screens.xcresult \
     --output-path build/screens-attachments
   jq -r '.[].attachments[] | "\(.exportedFileName)\t\(.suggestedHumanReadableName)"' \
     build/screens-attachments/manifest.json
   ```

   Expected: six rows mapping exported files to `01-home` … `06-home-sunset`.
   Copy each into `docs/screenshots/appstore/` under its canonical name
   (`01-home.png`, `02-ask.png`, `03-review.png`, `04-digest.png`,
   `05-settings.png`, `06-home-sunset.png`).

6. **Verify the dimensions.** Apple's 6.9-inch slot requires 1320 × 2868 px.

   ```bash
   sips -g pixelWidth -g pixelHeight ../docs/screenshots/appstore/*.png
   ```

   Expected: every file reports `pixelWidth: 1320` / `pixelHeight: 2868`.

## What the harness captures (for when you edit it)

`ios/KairoUITests/ScreenshotTests.swift` drives one test through the real app:

| Shot | Flow |
| --- | --- |
| `01-home` | Taps the "Load demo memories" seed banner, taps "Check in today" — the in-context notification permission alert fires **here**, and the harness taps Allow on the springboard alert — then waits for the Day-3 recall card. |
| `02-ask` | Taps the "What triggers my bloating?" suggestion and waits (≤ 90 s) for the generated, cited answer ("Remember this" appears). |
| `03-review` | Taps "Show answer" to reveal a due flashcard with its rating row. |
| `04-digest` | Waits (≤ 120 s) for the weekly reflection to generate. |
| `05-settings` | Opens Settings from Home and lets the widget previews render. |
| `06-home-sunset` | Selects the Sunset theme (the switch rebuilds the root view, dismissing the sheet) and captures Home in the signature look. |

## Troubleshooting

- **"seed banner should show on fresh install" fails** — the simulator wasn't
  erased (step 2), or a previous run already seeded it. Erase and rerun.
- **Ask or Digest step times out** — the cloud path isn't reachable: your local
  `AppConfig.swift` still has the committed `nil` values, `<your-proxy-url>` is
  wrong, or the proxy's daily cap is exhausted.
- **`Unable to find a device matching ... iPhone 17 Pro Max`** — create the
  simulator in Xcode (Settings → Platforms / Devices) and rerun from step 2.
- **Status bar shows the real time in the captures** — the override was applied
  before an erase, which resets it. Redo step 3 after step 2 and rerun.
- **A tap fails right after check-in** — if you moved the first check-in in the
  flow, move the `allowNotificationsIfAsked()` call with it; the permission
  alert must be dismissed where it fires.
- **`xcodebuild` errors that the result bundle already exists** — remove
  `build/screens.xcresult` from the previous run.

# How to sideload Kairō onto an iPhone with a free Apple ID

Install the current build on a physical iPhone using a free Apple ID (Personal Team) —
no paid Developer Program membership. Free-team builds expire after ~7 days;
re-running the deploy renews them.

## Prerequisites

- Full Xcode installed, with your Apple ID added under **Xcode → Settings → Accounts**.
- iPhone connected by cable and unlocked, with **Developer Mode** enabled
  (Settings → Privacy & Security → Developer Mode).
- The Xcode project generated: `cd ios && xcodegen generate` (only needed after
  `ios/project.yml` changes; `brew install xcodegen` if missing).

## 1. Collect the three identifiers

The deploy script (`scripts/deploy_device.sh`) reads three environment variables:

| Variable | What it is | Where to find it |
|---|---|---|
| `KAIRO_TEAM_ID` | Your (Personal) Team ID | Xcode → Settings → Accounts → select your team |
| `KAIRO_DEVICE_UDID` | Hardware UDID (used by `xcodebuild`) | `xcrun xctrace list devices` |
| `KAIRO_DEVICE_CORE` | CoreDevice identifier (used by `devicectl`) | `xcrun devicectl list devices` — the *Identifier* column |

Expected output: `xctrace` lists your phone with a UDID in parentheses;
`devicectl` lists it with a UUID-style Identifier. These are **two different IDs**.

## 2. Run the deploy script

From the repo root:

```bash
KAIRO_TEAM_ID=<your-team-id> \
KAIRO_DEVICE_UDID=<hardware-udid> \
KAIRO_DEVICE_CORE=<coredevice-id> \
bash scripts/deploy_device.sh
```

The script strips extended attributes, builds Debug into
`~/Library/Developer/KairoDeviceBuild`, installs with
`xcrun devicectl device install app`, and launches the bundle
`com.kairomemory.kairo`.

Expected output on a **paid** team: `✅ Kairō deployed & launched`, and the app
opens on the phone. On a **free** team, expect the failure in step 3.

## 3. Fix the free-team App Group failure

Free Personal Teams cannot provision App Groups, and both the app and widget
targets declare `group.com.kairomemory.kairo` (see `ios/project.yml`). The build
fails with:

> Provisioning profile … doesn't match the entitlements file's value for the
> com.apple.security.application-groups entitlement

Run the same build the script uses, but append `CODE_SIGN_ENTITLEMENTS=` (empty)
to strip the entitlements file from **both** targets, then install and launch
manually:

```bash
cd ios
xattr -cr Kairo Kairo.xcodeproj

xcodebuild \
  -project Kairo.xcodeproj \
  -scheme Kairo \
  -configuration Debug \
  -destination "platform=iOS,id=$KAIRO_DEVICE_UDID" \
  -allowProvisioningUpdates \
  -derivedDataPath "$HOME/Library/Developer/KairoDeviceBuild" \
  DEVELOPMENT_TEAM="$KAIRO_TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_ENTITLEMENTS= \
  build

APP="$HOME/Library/Developer/KairoDeviceBuild/Build/Products/Debug-iphoneos/Kairo.app"
xcrun devicectl device install app --device "$KAIRO_DEVICE_CORE" "$APP"
xcrun devicectl device process launch --device "$KAIRO_DEVICE_CORE" com.kairomemory.kairo
```

Expected output: `** BUILD SUCCEEDED **`, an install progress line from
`devicectl`, then a launch confirmation.

**Consequence:** without the App Group, the home-screen widget cannot read
streak data — it still installs but shows placeholder content
(`ios/KairoShared/StreakSnapshot.swift` returns `.empty` when the shared suite
is unavailable). Everything else works: check-in reminders deliberately read
`UserDefaults.standard` rather than the App Group
(`ios/Kairo/Core/Services/NotificationService.swift`) for exactly this case.

## 4. Trust the developer profile (first install only)

On first launch iOS blocks the app ("Untrusted Developer"). On the phone, go to
**Settings → General → VPN & Device Management**, tap your Apple ID under
*Developer App*, and tap **Trust**. Launch Kairō again.

Expected result: the app opens normally.

## 5. Renew before the 7-day expiry

Free-team signing lapses after roughly 7 days, after which the app refuses to
open. Re-run step 2 (plus step 3 on a free team) with the phone connected to
re-sign and reinstall; data on the device is preserved.

## Troubleshooting

- **`resource fork, Finder information, or similar detritus not allowed`** —
  codesign chokes on macOS extended attributes picked up from Desktop/iCloud
  folders. The script already builds into `~/Library/Developer/KairoDeviceBuild`
  (outside iCloud), runs `xattr -cr`, and re-signs by hand as a fallback. If you
  build manually, keep the `-derivedDataPath` outside Desktop/Documents and run
  `xattr -cr Kairo Kairo.xcodeproj` first.
- **Build succeeds but the phone isn't found by `devicectl`** — confirm the
  phone is unlocked and you passed the CoreDevice *Identifier* (not the hardware
  UDID) as `KAIRO_DEVICE_CORE`.
- **App stopped opening after a week** — free-team signing expired; see step 5.
- **You have a paid Developer account** — set the same three variables and run
  `scripts/deploy_device.sh` as-is: the App Group provisions normally, no
  entitlement stripping is needed, and the widget shows live streak data. For
  distribution builds see [../DEPLOYMENT.md](../DEPLOYMENT.md).

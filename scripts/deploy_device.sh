#!/usr/bin/env bash
# Build, sign, install & launch Kairō on the connected iPhone (Raj's iPhone 17 Pro Max).
#
# Re-run this anytime to:
#   • renew the ~7-day free-team signing (the app stops opening after that), or
#   • push code changes to the device.
#
# Requires: phone connected + unlocked, Developer Mode on, Apple ID in Xcode.
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

IOS_DIR="$(cd "$(dirname "$0")/../ios" && pwd)"
cd "$IOS_DIR"

# Fill these in (or pass as env vars). Find them with:
#   Team ID:     Xcode → Settings → Accounts → your team (or developer.apple.com)
#   Device UDID: xcrun xctrace list devices       (the hardware UDID, for xcodebuild)
#   CoreDevice:  xcrun devicectl list devices     (the Identifier column, for devicectl)
TEAM="${KAIRO_TEAM_ID:-YOUR_TEAM_ID}"
DEVICE_UDID="${KAIRO_DEVICE_UDID:-YOUR_DEVICE_UDID}"
DEVICE_CORE="${KAIRO_DEVICE_CORE:-YOUR_DEVICE_COREDEVICE_ID}"
BUNDLE_ID="com.kairomemory.kairo"
# Build OUTSIDE Desktop/iCloud so the .app doesn't pick up FinderInfo/fileprovider
# xattrs that make codesign fail ("resource fork … not allowed").
DERIVED="$HOME/Library/Developer/KairoDeviceBuild"

xattr -cr Kairo Kairo.xcodeproj 2>/dev/null || true

xcodebuild \
  -project Kairo.xcodeproj \
  -scheme Kairo \
  -configuration Debug \
  -destination "platform=iOS,id=$DEVICE_UDID" \
  -allowProvisioningUpdates \
  -derivedDataPath "$DERIVED" \
  DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_STYLE=Automatic \
  build

APP="$DERIVED/Build/Products/Debug-iphoneos/Kairo.app"

# Belt-and-suspenders: if signing didn't stick, strip detritus and re-sign by hand.
if ! codesign --verify --strict "$APP" 2>/dev/null; then
  echo "↻ re-signing after stripping xattrs…"
  ID=$(security find-identity -p codesigning -v | awk '/Apple Development/{print $2; exit}')
  XENT="$DERIVED/Build/Intermediates.noindex/Kairo.build/Debug-iphoneos/Kairo.build/Kairo.app.xcent"
  xattr -cr "$APP"
  [ -f "$APP/Kairo.debug.dylib" ] && codesign --force --sign "$ID" --timestamp=none --generate-entitlement-der "$APP/Kairo.debug.dylib"
  [ -f "$APP/__preview.dylib" ]   && codesign --force --sign "$ID" --timestamp=none --generate-entitlement-der "$APP/__preview.dylib"
  codesign --force --sign "$ID" --entitlements "$XENT" --timestamp=none --generate-entitlement-der "$APP"
fi

xcrun devicectl device install app --device "$DEVICE_CORE" "$APP"
xcrun devicectl device process launch --device "$DEVICE_CORE" "$BUNDLE_ID"
echo "✅ Kairō deployed & launched on Raj's iPhone."

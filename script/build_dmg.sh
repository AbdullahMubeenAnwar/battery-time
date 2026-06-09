#!/bin/bash
# Builds BatteryTime.app and packages it as a distributable DMG.
# Output: release/BatteryTime-<version>.dmg
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="BatteryTime"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
RELEASE_DIR="$ROOT_DIR/release"
STAGING_DIR="$ROOT_DIR/dist/dmg-staging"

# Read version from Info.plist (set by build_and_run.sh)
get_version() {
  /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" \
    "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || echo "1.0"
}

echo "→ Building $APP_NAME…"
"$ROOT_DIR/script/build_and_run.sh" build

VERSION="$(get_version)"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"

echo "→ Staging app bundle…"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

mkdir -p "$RELEASE_DIR"
rm -f "$DMG_PATH"

echo "→ Creating DMG…"
hdiutil create \
  -volname "Battery Time" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH" >/dev/null

rm -rf "$STAGING_DIR"

echo "✓ $DMG_PATH"

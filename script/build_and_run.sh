#!/bin/bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="BatteryTime"
BUNDLE_ID="com.abdullah.batterytime"
MIN_SYSTEM_VERSION="13.0"
# Release CI exports BATTERYTIME_VERSION from the git tag (e.g. 1.1).
# Falls back to a dev default for local builds.
APP_VERSION="${BATTERYTIME_VERSION:-1.0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"

stop_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  pkill -f "$APP_BINARY" >/dev/null 2>&1 || true
}

is_running() {
  pgrep -x "$APP_NAME" >/dev/null 2>&1 || pgrep -f "$APP_BINARY" >/dev/null 2>&1
}

stop_app

build_app() {
  if [[ "${BATTERYTIME_USE_SWIFTPM:-0}" == "1" ]] && swift build; then
    BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"
    return
  fi

  if [[ "${BATTERYTIME_USE_SWIFTPM:-0}" == "1" ]]; then
    echo "swift build failed; falling back to direct swiftc compilation." >&2
  fi

  local fallback_dir="$ROOT_DIR/.build/fallback/debug"
  mkdir -p "$fallback_dir"
  BUILD_BINARY="$fallback_dir/$APP_NAME"

  local source_files=()
  local source_list
  source_list="$(find "$ROOT_DIR/Sources/BatteryTime" -name '*.swift' -print | sort)"
  while IFS= read -r source_file; do
    [[ -n "$source_file" ]] || continue
    source_files+=("$source_file")
  done <<<"$source_list"

  # Pass -DHAS_MACOS26_SDK only when the active SDK actually declares the
  # macOS 26 glass APIs; older SDKs (e.g. macOS 15 on CI) cannot compile
  # those symbols even inside #available blocks.
  local sdk_flags=()
  local sdk_ver
  sdk_ver="$(xcrun --sdk macosx --show-sdk-version 2>/dev/null || true)"
  if [[ "${sdk_ver%%.*}" -ge 26 ]] 2>/dev/null; then
    sdk_flags=(-DHAS_MACOS26_SDK)
  fi

  xcrun swiftc \
	    -swift-version 5 \
	    -target "$(uname -m)-apple-macosx13.0" \
	    "${sdk_flags[@]+"${sdk_flags[@]}"}" \
	    -framework SwiftUI \
	    -framework AppKit \
	    -framework IOKit \
	    -framework ServiceManagement \
	    -o "$BUILD_BINARY" \
	    "${source_files[@]}"
}

build_app

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

# Copy app icon if present
APP_RESOURCES="$APP_CONTENTS/Resources"
ICON_SRC="$ROOT_DIR/Assets/AppIcon.icns"
if [[ -f "$ICON_SRC" ]]; then
  mkdir -p "$APP_RESOURCES"
  cp "$ICON_SRC" "$APP_RESOURCES/AppIcon.icns"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>Battery Time</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_VERSION</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
</dict>
</plist>
PLIST

codesign --force --deep --options runtime --sign - "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE" >/dev/null 2>&1
}

case "$MODE" in
  run)
    open_app
    ;;
  --build|build)
    # Build only — no launch. Used by build_dmg.sh and CI.
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    for _ in {1..20}; do
      if is_running; then
        echo "$APP_NAME is running"
        exit 0
      fi
      sleep 0.5
    done
    echo "$APP_NAME did not start within 10 seconds" >&2
    exit 1
    ;;
  *)
    echo "usage: $0 [run|build|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac

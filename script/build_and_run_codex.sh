#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PACKAGE_DIR="$ROOT_DIR"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_STAMP="$(date +%Y%m%d-%H%M%S)-$$"
RELEASE_DIR="$DIST_DIR/releases/$RELEASE_STAMP"
APP_DISPLAY_NAME="Token Cost App - OC Codex Ver"
APP_EXECUTABLE_NAME="CodexTokenCostApp"
HELPER_EXECUTABLE_NAME="CodexTokenCostHelper"
BUNDLE_ID="com.yanghaoran.CodexTokenCost"
MIN_SYSTEM_VERSION="14.0"
SWIFT_SDK_ROOT="$(xcrun --sdk macosx --show-sdk-path)"

APP_BUNDLE="$RELEASE_DIR/$APP_DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_HELPERS="$APP_CONTENTS/Helpers"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_EXECUTABLE_NAME"
HELPER_BINARY="$APP_HELPERS/$HELPER_EXECUTABLE_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.icns"

kill_running() {
  pkill -x "$APP_EXECUTABLE_NAME" >/dev/null 2>&1 || true
  pkill -x "$HELPER_EXECUTABLE_NAME" >/dev/null 2>&1 || true
  sleep 1
}

stage_bundle() {
  SWIFT_BUILD_FLAGS=(
    --disable-sandbox
    --sdk "$SWIFT_SDK_ROOT"
  )

  swift build "${SWIFT_BUILD_FLAGS[@]}"
  BUILD_BINARY_DIR="$(swift build "${SWIFT_BUILD_FLAGS[@]}" --show-bin-path)"

  mkdir -p "$APP_MACOS"
  mkdir -p "$APP_HELPERS"

  cp "$BUILD_BINARY_DIR/$APP_EXECUTABLE_NAME" "$APP_BINARY"
  cp "$BUILD_BINARY_DIR/$HELPER_EXECUTABLE_NAME" "$HELPER_BINARY"
  chmod +x "$APP_BINARY" "$HELPER_BINARY"
  mkdir -p "$APP_RESOURCES"
  if [[ -f "$ICON_SOURCE" ]]; then
    cp "$ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
  fi
  printf 'APPL????' > "$APP_CONTENTS/PkgInfo"

  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_EXECUTABLE_NAME</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

  codesign --force --deep --sign - "$APP_BUNDLE"
}

launch_bundle() {
  /usr/bin/open -n "$APP_BUNDLE"
}

kill_running
stage_bundle

case "$MODE" in
  run)
    launch_bundle
    ;;
  build)
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    launch_bundle
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_EXECUTABLE_NAME\""
    ;;
  --telemetry|telemetry)
    launch_bundle
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    launch_bundle
    sleep 2
    pgrep -x "$APP_EXECUTABLE_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|build|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac

#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="CodexPet.app"
APP_DIR="$DIST_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE_PATH="$ROOT_DIR/.build/arm64-apple-macosx/release/CodexPet"
ICON_SCRIPT="$ROOT_DIR/Scripts/generate-icon.swift"
ICON_PATH="$ROOT_DIR/AppBundle/AppIcon.icns"

swift build -c release --package-path "$ROOT_DIR"
swift "$ICON_SCRIPT" "$ROOT_DIR"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/AppBundle/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/CodexPet"
cp "$ICON_PATH" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$MACOS_DIR/CodexPet"

codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "$APP_DIR"

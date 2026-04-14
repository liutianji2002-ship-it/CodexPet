#!/bin/zsh

set -euo pipefail

TARGET_PLIST="$HOME/Library/LaunchAgents/com.liutianji.codexpet.plist"

launchctl bootout "gui/$(id -u)" "$TARGET_PLIST" >/dev/null 2>&1 || true
rm -f "$TARGET_PLIST"

echo "removed $TARGET_PLIST"

#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
BIN_DIR="$BUILD_DIR/arm64-apple-macosx/release"
APP_NAME="Mon.app"
APP_DIR="$BUILD_DIR/$APP_NAME"

echo "==> Building Mon..."

# 1. Build CLI + App
cd "$PROJECT_DIR"
swift build -c release --product mon
swift build -c release --product MonApp

# 2. Package .app bundle
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_DIR/MonApp" "$APP_DIR/Contents/MacOS/MonApp"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/"

# 3. Install CLI symlink
CLI_BIN="$BIN_DIR/mon"
echo "==> CLI binary: $CLI_BIN"
echo "    To install: ln -sf $CLI_BIN /usr/local/bin/mon"

# 4. Done
echo "==> Built: $APP_DIR"
echo "    To run: open $APP_DIR"
echo "    To install: cp -r $APP_DIR /Applications/"

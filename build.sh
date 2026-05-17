#!/bin/bash
set -e

APP_NAME="ClaudeNotify"
BUNDLE_ID="com.claude.notify"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/claude-notify" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

echo "Done: $APP_BUNDLE"
echo ""
echo "Install with:"
echo "  cp -r $APP_BUNDLE /Applications/"
echo ""
echo "Run daemon:"
echo "  open /Applications/$APP_NAME.app"
echo ""
echo "CLI wrapper (add to ~/.zshrc):"
echo "  alias claude-notify='/Applications/$APP_NAME.app/Contents/MacOS/$APP_NAME'"

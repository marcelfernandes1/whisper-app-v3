#!/bin/bash

# Bundle the Python daemon first
echo "Bundling Python daemon..."
./bundle_daemon.sh

# Build the Swift app
echo "Building WhisperTranscribe..."
swift build -c release

# Create app bundle structure
APP_NAME="WhisperTranscribe"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp ".build/release/$APP_NAME" "$MACOS_DIR/"

# Copy Info.plist
cp "Info.plist" "$CONTENTS_DIR/"

# Copy icon
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES_DIR/"
    echo "Icon added to app bundle"
fi

# Copy bundled daemon
if [ -f "dist_daemon/transcribe_daemon" ]; then
    cp "dist_daemon/transcribe_daemon" "$RESOURCES_DIR/"
    chmod +x "$RESOURCES_DIR/transcribe_daemon"
    echo "Bundled daemon added to app bundle"
else
    echo "⚠️  Warning: Bundled daemon not found. App will not work!"
fi

echo "App bundle created: $APP_BUNDLE"
echo "To install, drag $APP_BUNDLE to /Applications"
echo ""
echo "Remember to:"
echo "1. Grant microphone permissions"
echo "2. Grant accessibility permissions in System Preferences"

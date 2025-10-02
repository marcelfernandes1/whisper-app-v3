#!/bin/bash

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

echo "App bundle created: $APP_BUNDLE"
echo "To install, drag $APP_BUNDLE to /Applications"
echo ""
echo "Remember to:"
echo "1. Grant microphone permissions"
echo "2. Grant accessibility permissions in System Preferences"

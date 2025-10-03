#!/bin/bash

APP_NAME="WhisperTranscribe"
VERSION="1.0"
DMG_NAME="${APP_NAME}-${VERSION}"
VOLUME_NAME="${APP_NAME}"

# Clean up any existing DMG
rm -f "${DMG_NAME}.dmg"
rm -rf dmg_temp

# Create temporary directory for DMG contents
echo "Creating DMG staging directory..."
mkdir -p dmg_temp

# Copy the app bundle
echo "Copying ${APP_NAME}.app..."
cp -R "${APP_NAME}.app" dmg_temp/

# Create Applications symlink for easy installation
echo "Creating Applications symlink..."
ln -s /Applications dmg_temp/Applications

# Create the DMG
echo "Creating DMG..."
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder dmg_temp \
    -ov \
    -format UDZO \
    "${DMG_NAME}.dmg"

# Clean up
rm -rf dmg_temp

# Verify the DMG was created
if [ -f "${DMG_NAME}.dmg" ]; then
    echo ""
    echo "✅ DMG created successfully: ${DMG_NAME}.dmg"
    ls -lh "${DMG_NAME}.dmg"
    echo ""
    echo "Users can install by:"
    echo "1. Double-click ${DMG_NAME}.dmg"
    echo "2. Drag ${APP_NAME}.app to Applications folder"
    echo "3. Eject the volume"
    echo "4. Launch ${APP_NAME} from Applications"
else
    echo "❌ Failed to create DMG"
    exit 1
fi

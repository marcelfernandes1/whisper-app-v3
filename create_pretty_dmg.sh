#!/bin/bash

APP_NAME="WhisperTranscribe"
VERSION="1.0"
DMG_NAME="${APP_NAME}-${VERSION}"
VOLUME_NAME="${APP_NAME}"
DMG_BACKGROUND="dmg_background.png"

# Clean up
rm -f "${DMG_NAME}.dmg"
rm -rf dmg_temp

# Create temp directory
echo "Creating DMG staging directory..."
mkdir -p dmg_temp/.background

# Copy the app
echo "Copying ${APP_NAME}.app..."
cp -R "${APP_NAME}.app" dmg_temp/

# Copy background image
if [ -f "$DMG_BACKGROUND" ]; then
    cp "$DMG_BACKGROUND" dmg_temp/.background/
    echo "Background image added"
fi

# Create Applications symlink
echo "Creating Applications symlink..."
ln -s /Applications dmg_temp/Applications

# Create a temporary writable DMG
echo "Creating temporary DMG..."
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder dmg_temp \
    -ov \
    -format UDRW \
    "temp_${DMG_NAME}.dmg"

# Mount the DMG
echo "Mounting DMG..."
MOUNT_DIR="/Volumes/${VOLUME_NAME}"
hdiutil attach "temp_${DMG_NAME}.dmg"

# Give it a moment to mount
sleep 2

# Run AppleScript to set the visual style
echo "Styling DMG window..."
osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 1060, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background picture of viewOptions to file ".background:${DMG_BACKGROUND}"

        -- Position the app icon (left side, centered)
        set position of item "${APP_NAME}.app" of container window to {165, 200}

        -- Position the Applications link (right side, centered)
        set position of item "Applications" of container window to {495, 200}

        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Sync and unmount
sync
echo "Unmounting..."
hdiutil detach "${MOUNT_DIR}"

# Convert to compressed read-only
echo "Converting to final DMG..."
hdiutil convert "temp_${DMG_NAME}.dmg" \
    -format UDZO \
    -o "${DMG_NAME}.dmg"

# Clean up
rm -f "temp_${DMG_NAME}.dmg"
rm -rf dmg_temp

# Verify
if [ -f "${DMG_NAME}.dmg" ]; then
    echo ""
    echo "✅ Beautiful DMG created: ${DMG_NAME}.dmg"
    ls -lh "${DMG_NAME}.dmg"
    echo ""
    echo "Installation:"
    echo "1. Double-click ${DMG_NAME}.dmg"
    echo "2. Drag ${APP_NAME}.app to Applications"
    echo "3. Done!"
else
    echo "❌ Failed to create DMG"
    exit 1
fi

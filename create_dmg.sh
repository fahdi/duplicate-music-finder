#!/bin/bash

APP_NAME="DuplicateMusicFinder"
DMG_NAME="${APP_NAME}.dmg"
VOL_NAME="${APP_NAME}"

echo "Preparing DMG generation..."

# Clean up previous artifacts
rm -f "${DMG_NAME}"
rm -rf "dmg_temp"

# Create temporary folder for DMG contents
mkdir "dmg_temp"

# Copy the App Bundle
echo "Copying App Bundle..."
cp -r "${APP_NAME}.app" "dmg_temp/"

# Create symlink to /Applications for easy drag-and-drop
echo "Creating Applications link..."
ln -s /Applications "dmg_temp/Applications"

# Create the DMG using hdiutil (built-in macOS tool)
echo "Creating DMG..."
hdiutil create -volname "${VOL_NAME}" -srcfolder "dmg_temp" -ov -format UDZO "${DMG_NAME}"

# Cleanup
echo "Cleaning up..."
rm -rf "dmg_temp"

echo "DMG Created: ${DMG_NAME}"

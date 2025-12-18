#!/bin/bash

APP_NAME="DuplicateMusicFinder"
BUILD_DIR=".build/debug"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Building..."
swift build

echo "Creating Bundle Structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "Copying Executable..."
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"

echo "Copying Info.plist..."
cp Info.plist "${CONTENTS_DIR}/"

if [ -f "AppIcon.icns" ]; then
    echo "Copying AppIcon..."
    cp "AppIcon.icns" "${RESOURCES_DIR}/"
fi

echo "Signing (Ad-Hoc)..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Done! You can run open ${APP_BUNDLE}"

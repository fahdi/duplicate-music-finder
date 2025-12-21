#!/bin/bash
# Bundle metaflac and dependencies into app Resources
# This script ensures FLAC artwork embedding works out-of-the-box

set -e

echo "📦 Bundling metaflac for FLAC artwork support..."

# Create bin directory in Resources
mkdir -p Resources/bin

# Check if metaflac is installed
if ! command -v metaflac &> /dev/null; then
    echo "❌ metaflac not found. Installing via Homebrew..."
    brew install flac
fi

# Get metaflac path
METAFLAC_PATH=$(which metaflac)
echo "✅ Found metaflac at: $METAFLAC_PATH"

# Copy metaflac binary
cp "$METAFLAC_PATH" Resources/bin/

# Get library dependencies
FLAC_LIB=$(otool -L "$METAFLAC_PATH" | grep libFLAC | awk '{print $1}')
OGG_LIB=$(otool -L "$METAFLAC_PATH" | grep libogg | awk '{print $1}')

echo "📚 Copying dependencies:"
echo "  - $FLAC_LIB"
echo "  - $OGG_LIB"

# Copy libraries
cp "$FLAC_LIB" Resources/bin/
cp "$OGG_LIB" Resources/bin/

# Fix library paths to use @executable_path (relative to app bundle)
echo "🔗 Relinking libraries..."
install_name_tool -change "$FLAC_LIB" @executable_path/../Resources/bin/libFLAC.14.dylib Resources/bin/metaflac
install_name_tool -change "$OGG_LIB" @executable_path/../Resources/bin/libogg.0.dylib Resources/bin/metaflac

# Re-sign binaries (required after modifying)
echo "✍️  Code signing..."
codesign --force --sign - Resources/bin/metaflac Resources/bin/libFLAC.14.dylib Resources/bin/libogg.0.dylib

# Verify
echo ""
echo "✅ Bundling complete! Library dependencies:"
otool -L Resources/bin/metaflac

echo ""
echo "🎉 metaflac is now bundled and ready for distribution!"

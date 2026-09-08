#!/bin/bash
# Build Starfall.app bundle for macOS
# Usage: ./Scripts/build_app_bundle.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/.build/release"
APP_NAME="Starfall"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

echo "Building Starfall.app bundle..."

# Build in release mode
echo "Step 1: Building release binary..."
cd "$PROJECT_ROOT"
swift build -c release 2>&1

# Create .app bundle structure
echo "Step 2: Creating app bundle structure..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/StarfallApp" "$APP_DIR/Contents/MacOS/Starfall"

# Copy Info.plist
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

# Copy entitlements
cp "$PROJECT_ROOT/Resources/StarfallApp.entitlements" "$APP_DIR/Contents/StarfallApp.entitlements"

# Copy app icon
if [ -f "$PROJECT_ROOT/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
    echo "  Copied AppIcon.icns"
fi

# Copy SVG assets to Resources
echo "Step 3: Copying SVG assets..."
cp -r "$PROJECT_ROOT/Assets/svg" "$APP_DIR/Contents/Resources/svg"

# Fix Info.plist paths for bundle
# Update CFBundleExecutable to point to the actual binary name
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable Starfall" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true

echo ""
echo "App bundle created at: $APP_DIR"
echo ""
echo "To install:"
echo "  cp -r '$APP_DIR' /Applications/"
echo ""
echo "To launch:"
echo "  open '$APP_DIR'"

#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="Starfall"
BUNDLE_ID="com.starfall.app"
APP_BUNDLE="build/${APP_NAME}.app"
DMG_FILE="build/${APP_NAME}.dmg"

echo "=== Building Starfall macOS app bundle ==="

# 1. Release build
echo "[1/4] Building release..."
swift build -c release

# 2. Create app bundle structure
echo "[2/4] Creating app bundle..."
rm -rf "build/${APP_NAME}.app"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp .build/release/StarfallApp "${APP_BUNDLE}/Contents/MacOS/"

# Copy resources
cp Resources/Info.plist "${APP_BUNDLE}/Contents/"
cp Resources/AppIcon.icns "${APP_BUNDLE}/Contents/Resources/"

echo "[3/4] Code signing..."
# Sign with ad-hoc signature (required for local execution)
codesign --force --entitlements Resources/StarfallApp.entitlements \
    --sign - "${APP_BUNDLE}"

echo "App bundle ready: ${APP_BUNDLE}"

# 4. Create DMG
echo "[4/4] Creating DMG..."
rm -f "$DMG_FILE"
hdiutil create -size 50m -volname "${APP_NAME}" -fs HFS+ -srcfolder "build/${APP_NAME}.app" "$DMG_FILE"

echo ""
echo "=== Done ==="
echo "App bundle: ${APP_BUNDLE}"
echo "DMG:        ${DMG_FILE}"
echo ""
echo "To test: open build/${APP_NAME}.app"
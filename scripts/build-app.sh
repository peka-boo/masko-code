#!/bin/bash
# Build Masko Code app bundle and DMG for macOS
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/.build"
APP_NAME="Masko Code.app"
APP_PATH="$BUILD_DIR/$APP_NAME"
DMG_PATH="$PROJECT_ROOT/Masko Code.dmg"

echo "=== Building Masko Code for macOS ==="

# Step 1: Build release binary
echo "📦 Building release binary..."
cd "$PROJECT_ROOT"
swift build -c release

# Step 2: Create app bundle structure
echo "📁 Creating app bundle structure..."
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Step 3: Copy binary
echo "📋 Copying binary..."
cp "$BUILD_DIR/release/masko-code" "$APP_PATH/Contents/MacOS/masko-code"

# Step 4: Copy Info.plist
echo "📋 Copying Info.plist..."
cp "$PROJECT_ROOT/Info.plist" "$APP_PATH/Contents/Info.plist"

# Step 5: Copy resources
echo "📋 Copying resources..."
cp -R "$PROJECT_ROOT/Sources/Resources/"* "$APP_PATH/Contents/Resources/"

# Step 6: Copy Sparkle framework (for auto-updates)
echo "📋 Copying Sparkle framework..."
mkdir -p "$APP_PATH/Contents/Frameworks"
if [ -d "$BUILD_DIR/release/Sparkle.framework" ]; then
    cp -R "$BUILD_DIR/release/Sparkle.framework" "$APP_PATH/Contents/Frameworks/"
fi

# Step 7: Add rpath for embedded frameworks
echo "🔧 Adding framework rpath..."
install_name_tool -add_rpath "@loader_path/../Frameworks" "$APP_PATH/Contents/MacOS/masko-code" 2>/dev/null || true

# Step 8: Sign the app (ad-hoc for local installation)
echo "✍️  Signing app with ad-hoc signature..."
codesign --force --deep --sign - "$APP_PATH"

# Step 9: Verify the app
echo "✅ Verifying app..."
spctl --assess --verbose=4 --type execute "$APP_PATH" 2>&1 || true

echo "✅ App bundle created: $APP_PATH"

# Step 10: Create DMG
echo "📀 Creating DMG installer..."
"$SCRIPT_DIR/create-dmg.sh" \
    "$APP_PATH" \
    "$DMG_PATH" \
    "Masko Code" \
    "$SCRIPT_DIR/dmg-background.py"

echo ""
echo "=== Build Complete ==="
echo "📱 App: $APP_PATH"
echo "📀 DMG: $DMG_PATH"
echo ""
echo "To install: Open the DMG and drag Masko Code to Applications folder"

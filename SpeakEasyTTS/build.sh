#!/bin/bash

# SpeakEasyTTS Build Script
# Creates a proper macOS .app bundle from Swift Package

set -e

# Configuration
APP_NAME="SpeakEasyTTS"
BUNDLE_ID="com.speakeasy.tts"
VERSION="1.0.0"
BUILD_DIR="build"
RELEASE_DIR="$BUILD_DIR/release"

echo "🔨 Building $APP_NAME..."

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$RELEASE_DIR"

# Workaround for broken CLT linker installs where /usr/bin/ld is empty.
# SwiftPM manifest compilation uses swiftc directly, so we inject SWIFT_EXEC
# with a wrapper that forces ld-classic.
CLT_LD="/Library/Developer/CommandLineTools/usr/bin/ld"
CLT_LD_CLASSIC="/Library/Developer/CommandLineTools/usr/bin/ld-classic"
if [ -f "$CLT_LD" ] && [ ! -s "$CLT_LD" ] && [ -x "$CLT_LD_CLASSIC" ]; then
    echo "⚠️  Detected empty CLT linker at $CLT_LD"
    echo "   Using ld-classic via SWIFT_EXEC wrapper for this build."
    SWIFTC_WRAPPER="$BUILD_DIR/swiftc-wrapper.sh"
    cat > "$SWIFTC_WRAPPER" << EOF
#!/bin/bash
exec /Library/Developer/CommandLineTools/usr/bin/swiftc -use-ld=/Library/Developer/CommandLineTools/usr/bin/ld-classic "\$@"
EOF
    chmod +x "$SWIFTC_WRAPPER"
    export SWIFT_EXEC="$PWD/$SWIFTC_WRAPPER"
fi

# Build the executable
echo "📦 Compiling Swift package..."
swift build -c release

# Get the built executable path
EXECUTABLE_PATH=".build/release/$APP_NAME"

if [ ! -f "$EXECUTABLE_PATH" ]; then
    echo "❌ Build failed: executable not found at $EXECUTABLE_PATH"
    exit 1
fi

# Create app bundle structure
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📁 Creating app bundle structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Create Info.plist
echo "📝 Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SpeakEasy TTS</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 SpeakEasy. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Create PkgInfo
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "✅ Build complete!"
echo "📍 App bundle created at: $APP_BUNDLE"
echo ""
echo "To install:"
echo "  cp -r '$APP_BUNDLE' /Applications/"
echo ""
echo "To run:"
echo "  open '$APP_BUNDLE'"

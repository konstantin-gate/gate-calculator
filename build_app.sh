#!/bin/bash
set -e

APP_NAME="GateCalc"
BUILD_DIR=".build/release"
EXECUTABLE="$BUILD_DIR/CalculatorApp"
APP_BUNDLE="${APP_NAME}.app"

echo "=== Building ${APP_NAME} ==="
swift build -c release

echo ""
echo "=== Creating ${APP_BUNDLE} ==="

# Clean previous build
rm -rf "$APP_BUNDLE"

# Create bundle structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "$EXECUTABLE" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Create Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>GateCalc</string>
    <key>CFBundleIdentifier</key>
    <string>com.gatecalc.calculator</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>GateCalc</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMainNibFile</key>
    <string></string>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
EOF

# Make executable runnable
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo ""
echo "=== Build complete! ==="
echo "Launch with: open ./${APP_BUNDLE}"
echo "Or double-click in Finder: ${APP_BUNDLE}"

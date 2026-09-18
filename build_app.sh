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

# Convert PNG icon to .icns
ICONSET_DIR=$(mktemp -d)
ICONSET="${ICONSET_DIR}/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -z 16 16     Sources/Resources/app_icon.png --out "${ICONSET}/icon_16x16.png" >/dev/null
sips -z 32 32     Sources/Resources/app_icon.png --out "${ICONSET}/icon_16x16@2x.png" >/dev/null
sips -z 32 32     Sources/Resources/app_icon.png --out "${ICONSET}/icon_32x32.png" >/dev/null
sips -z 64 64     Sources/Resources/app_icon.png --out "${ICONSET}/icon_32x32@2x.png" >/dev/null
sips -z 128 128   Sources/Resources/app_icon.png --out "${ICONSET}/icon_128x128.png" >/dev/null
sips -z 256 256   Sources/Resources/app_icon.png --out "${ICONSET}/icon_128x128@2x.png" >/dev/null
sips -z 256 256   Sources/Resources/app_icon.png --out "${ICONSET}/icon_256x256.png" >/dev/null
sips -z 512 512   Sources/Resources/app_icon.png --out "${ICONSET}/icon_256x256@2x.png" >/dev/null
sips -z 512 512   Sources/Resources/app_icon.png --out "${ICONSET}/icon_512x512.png" >/dev/null
sips -z 1024 1024 Sources/Resources/app_icon.png --out "${ICONSET}/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"

# Copy localizations
cp -R Sources/Localization/en.lproj "${APP_BUNDLE}/Contents/Resources/"
cp -R Sources/Localization/ru.lproj "${APP_BUNDLE}/Contents/Resources/"

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
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

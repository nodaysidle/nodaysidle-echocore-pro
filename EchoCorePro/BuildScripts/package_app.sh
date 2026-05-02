#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="EchoCorePro"
BUILD_DIR="$ROOT/Build"
APP="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

cd "$ROOT"

for required in \
    "Runtime/backend.py" \
    "Runtime/venv" \
    "Models" \
    "Resources/AppIcon.icns"
do
    if [[ ! -e "$ROOT/$required" ]]; then
        echo "Missing required packaging input: $required" >&2
        exit 1
    fi
done

swift build -c release

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

cp ".build/release/$APP_NAME" "$MACOS/$APP_NAME"
cp -R Runtime "$RESOURCES/Runtime"
cp -R Models "$RESOURCES/Models"
cp Resources/AppIcon.icns "$RESOURCES/AppIcon.icns"

find "$RESOURCES/Runtime" -type d -name "__pycache__" -prune -exec rm -rf {} +
find "$RESOURCES/Runtime" -type f -name "*.pyc" -delete

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>EchoCorePro</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>pro.nodaysidle.echocorepro</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>EchoCore Pro</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>EchoCore Pro records audio locally for on-device transcription.</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

xattr -cr "$APP" || true
codesign --force --deep --sign - "$APP"

rm -rf "/Applications/$APP_NAME.app"
cp -R "$APP" /Applications/
xattr -cr "/Applications/$APP_NAME.app" || true

echo "Installed /Applications/$APP_NAME.app"

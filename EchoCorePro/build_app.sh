#!/bin/bash

# Build EchoCorePro as a standalone macOS app for Alpha Testing

set -e

echo "==========================================="
echo "  Building EchoCorePro for Alpha Testing"
echo "==========================================="
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf .build/
rm -rf EchoCorePro.app

# Build the executable
echo "🔨 Compiling Swift (release mode)..."
swift build -c release

# Create app bundle structure
echo "📦 Creating app bundle..."
mkdir -p "EchoCorePro.app/Contents/MacOS"
mkdir -p "EchoCorePro.app/Contents/Resources"
mkdir -p "EchoCorePro.app/Contents/Resources/Scripts"

# Copy executable
cp .build/release/EchoCorePro "EchoCorePro.app/Contents/MacOS/"

# Bundle Python scripts
echo "📜 Bundling Python scripts..."
cp Scripts/openvoice_server.py "EchoCorePro.app/Contents/Resources/Scripts/"
cp Scripts/start_server.sh "EchoCorePro.app/Contents/Resources/Scripts/"
chmod +x "EchoCorePro.app/Contents/Resources/Scripts/start_server.sh"

# Bundle checkpoints if they exist
if [ -d "checkpoints" ]; then
    echo "🤖 Bundling model checkpoints..."
    cp -r checkpoints "EchoCorePro.app/Contents/Resources/"
fi

# Create Info.plist
cat > "EchoCorePro.app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>EchoCorePro</string>
    <key>CFBundleIdentifier</key>
    <string>com.echocore.EchoCorePro</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>EchoCorePro</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0-alpha</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 EchoCore</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>EchoCorePro needs access to your microphone for voice recording and cloning.</string>
</dict>
</plist>
EOF

# Create Alpha README
cat > "EchoCorePro.app/Contents/Resources/ALPHA_README.txt" << 'EOF'
EchoCorePro Alpha v1.0.0
========================

REQUIREMENTS:
- macOS 14.0 (Sonoma) or later
- Python 3.11+ with pip
- Microphone access permission

FEATURES:
- Voice cloning from microphone recording or WAV file upload
- Text-to-speech synthesis with cloned voice
- Support for 17 languages including Italian
- Advanced synthesis settings (temperature, top_p, etc.)

SETUP:
The Python server should auto-start with the app.
If it doesn't, manually start it:

1. cd /path/to/EchoCorePro.app/Contents/Resources/Scripts
2. ./start_server.sh

USAGE:
1. Launch EchoCorePro.app
2. Go to Voice Cloning tab
3. Record your voice (6+ seconds) OR upload a WAV file
4. Click "Clone My Voice"
5. Enter text and click "Generate Speech"

KNOWN LIMITATIONS:
- First run may take longer as models download
- Large text synthesis may take time

FEEDBACK:
Please report issues to the development team.
EOF

# Make executable
chmod +x "EchoCorePro.app/Contents/MacOS/EchoCorePro"

echo ""
echo "==========================================="
echo "  Build Complete!"
echo "==========================================="
echo ""
echo "📍 App location: $(pwd)/EchoCorePro.app"
echo "📋 Version: 1.0.0-alpha"
echo "🖥️  Target: macOS 14.0+"
echo ""
echo "To run the app:"
echo "   open EchoCorePro.app"
echo ""

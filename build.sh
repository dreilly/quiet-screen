#!/bin/sh
set -eu
cd "$(dirname "$0")"
swift build -c release
swift Scripts/generate-icon.swift Assets
iconutil -c icns Assets/AppIcon.iconset -o Assets/AppIcon.icns
APP="$PWD/dist/Quiet Screen.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp .build/release/QuietScreen "$APP/Contents/MacOS/QuietScreen"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>QuietScreen</string>
<key>CFBundleIdentifier</key><string>local.daniel.quietscreen</string>
<key>CFBundleName</key><string>Quiet Screen</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built: $APP"

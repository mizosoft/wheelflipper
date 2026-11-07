#!/bin/sh
# Builds build/WheelFlipper.app (a background app with no Dock icon).
set -e
cd "$(dirname "$0")"

APP=build/WheelFlipper.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -o "$APP/Contents/MacOS/WheelFlipper" Sources/main.swift

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>io.github.mizosoft.wheelflipper</string>
    <key>CFBundleName</key><string>WheelFlipper</string>
    <key>CFBundleExecutable</key><string>WheelFlipper</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# Sign with the local certificate from make-cert.sh when it exists, so the
# Accessibility permission survives rebuilds; otherwise sign ad hoc.
IDENTITY="WheelFlipper Local Signing"
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
    codesign --force --sign "$IDENTITY" "$APP"
else
    echo "Note: run ./make-cert.sh once so rebuilds keep the Accessibility permission."
    codesign --force --sign - "$APP"
fi
echo "Built $APP"

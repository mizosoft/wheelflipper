#!/bin/sh
# Installs WheelFlipper to ~/Applications and starts it at login via launchd.
set -e
cd "$(dirname "$0")"
./build.sh

DEST="$HOME/Applications/WheelFlipper.app"
AGENT="$HOME/Library/LaunchAgents/io.github.mizosoft.wheelflipper.plist"

launchctl bootout "gui/$(id -u)" "$AGENT" 2>/dev/null || true
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
rm -rf "$DEST"
cp -R build/WheelFlipper.app "$DEST"

cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>io.github.mizosoft.wheelflipper</string>
    <key>ProgramArguments</key>
    <array><string>$DEST/Contents/MacOS/WheelFlipper</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key>
    <dict><key>SuccessfulExit</key><false/></dict>
    <key>StandardOutPath</key><string>/tmp/wheelflipper.log</string>
    <key>StandardErrorPath</key><string>/tmp/wheelflipper.log</string>
</dict>
</plist>
PLIST

launchctl bootstrap "gui/$(id -u)" "$AGENT"
echo "Installed. Grant Accessibility to WheelFlipper if prompted."

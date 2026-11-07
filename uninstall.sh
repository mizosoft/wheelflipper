#!/bin/sh
AGENT="$HOME/Library/LaunchAgents/io.github.mizosoft.wheelflipper.plist"
launchctl bootout "gui/$(id -u)" "$AGENT" 2>/dev/null || true
rm -f "$AGENT"
rm -rf "$HOME/Applications/WheelFlipper.app"
echo "Uninstalled. You can remove WheelFlipper from Accessibility in System Settings."

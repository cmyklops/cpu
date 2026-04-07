#!/bin/bash

set -e

RELEASE_APP="/Users/mattwesdock/Library/Developer/Xcode/DerivedData/CPUMeter-gcddwpcetlooefbvbkovmvderiuo/Build/Products/Release/CPUMeter.app"
DMG_NAME="CPUMeter.dmg"
TEMP_DIR=$(mktemp -d)
DMG_PATH="$TEMP_DIR/CPUMeter_Build"

# Create the DMG structure
mkdir -p "$DMG_PATH"
cp -r "$RELEASE_APP" "$DMG_PATH/"
ln -s /Applications "$DMG_PATH/Applications"

# Create DMG
hdiutil create -volname "CPUMeter" -srcfolder "$DMG_PATH" -ov -format UDZO "$DMG_NAME" 2>&1 | tail -3

# Verify DMG was created
if [ -f "$DMG_NAME" ]; then
    SIZE=$(du -h "$DMG_NAME" | cut -f1)
    echo "✓ DMG created: $DMG_NAME ($SIZE)"
    ls -lh "$DMG_NAME" | awk '{print "  File size:", $5, "- Created:", $6, $7, $8}'
else
    echo "✗ DMG creation failed"
    exit 1
fi

# Cleanup
rm -rf "$TEMP_DIR"

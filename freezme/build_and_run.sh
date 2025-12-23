#!/bin/bash

echo "🚀 Freezme App Build Script"
echo "=============================="
echo ""

# Set PATH
export PATH="/usr/local/bin:$PATH"

# Device ID
DEVICE_ID="616D8157-759E-4A43-93DD-F1B0A460A5B6"

echo "📱 Target Device: iPhone 17 Pro"
echo "🆔 Device ID: $DEVICE_ID"
echo ""

# Check if simulator is booted
echo "✅ Checking simulator status..."
if xcrun simctl list devices | grep "$DEVICE_ID" | grep -q "Booted"; then
    echo "✅ Simulator is booted and ready"
else
    echo "⚠️  Booting simulator..."
    xcrun simctl boot "$DEVICE_ID"
    sleep 3
fi
echo ""

# Try flutter run with verbose output
echo "🔨 Building and running app..."
echo "⏳ This may take 2-3 minutes for first build..."
echo ""

flutter run -d "$DEVICE_ID" --verbose 2>&1 | tee build.log

echo ""
echo "=============================="
echo "Build log saved to: build.log"

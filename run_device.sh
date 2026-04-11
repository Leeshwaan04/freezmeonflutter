#!/bin/bash
# Run Freezme on connected iPhone — works around macOS FinderInfo xattr signing issue
set -e

DEVICE_ID="00008110-0018451A1EE0401E"
BUNDLE_ID="com.sumitbagewadi.freezme"
WORKSPACE="/Users/sumitbagewadi/Documents/freezmeonflutter/freezme/ios/Runner.xcworkspace"
DERIVED="/Users/sumitbagewadi/Library/Developer/Xcode/DerivedData"

echo "🔨 Building..."
cd /Users/sumitbagewadi/Documents/freezmeonflutter/freezme
flutter build ios --debug --no-codesign 2>&1 | tail -5

echo "📦 Compiling with Xcode..."
xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme Runner \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  FLUTTER_BUILD_MODE=debug \
  build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | grep -iv "typedef\|Restore\|-F/" | tail -5

APP=$(find "$DERIVED/Runner-"*/Build/Products/Debug-iphoneos -name "Runner.app" -type d 2>/dev/null | head -1)
echo "📲 Installing: $APP"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"

echo "🚀 Launching..."
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"
echo "✅ Done — app is running on device"

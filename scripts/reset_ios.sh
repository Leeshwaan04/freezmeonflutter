#!/bin/bash

# Freezme iOS Hard Reset
# Run whenever builds break or after major dependency changes.
# Usage: ./scripts/reset_ios.sh [--full]
#   --full   Also wipes Flutter build cache (slower, use if dart issues persist)

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="$REPO_ROOT/freezme"
IOS_DIR="$FLUTTER_DIR/ios"

echo "── Freezme iOS Reset ──────────────────────────────────────────"
echo "  Working dir: $FLUTTER_DIR"

# ── 1. Kill stray Xcode / simulator processes ──────────────────────
echo ""
echo "1/5  Killing stray Xcode helper processes..."
pkill -9 "Xcode" 2>/dev/null || true
pkill -9 "com.apple.CoreSimulator.CoreSimulatorService" 2>/dev/null || true

# ── 2. Remove iOS derived data ─────────────────────────────────────
echo "2/5  Removing DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData

# ── 3. Wipe CocoaPods state ────────────────────────────────────────
echo "3/5  Wiping CocoaPods state..."
cd "$IOS_DIR"
rm -rf Pods
rm -f Podfile.lock

# ── 4. Flutter clean + pub get ─────────────────────────────────────
echo "4/5  Running flutter clean and pub get..."
cd "$FLUTTER_DIR"
if [[ "$1" == "--full" ]]; then
  flutter clean
  echo "     (--full) Flutter build cache cleared."
fi
flutter pub get

# ── 5. Reinstall pods ──────────────────────────────────────────────
echo "5/5  Reinstalling pods..."
cd "$IOS_DIR"
pod install --repo-update

echo ""
echo "✅  iOS reset complete."
echo "   Open Runner.xcworkspace in Xcode (NOT .xcodeproj) and build."

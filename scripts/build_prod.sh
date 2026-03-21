#!/bin/bash

# Freezme Production Build Script
# Produces a signed IPA ready for App Store Connect upload.
# Prerequisites: provisioning profile + cert installed in Keychain,
#                ExportOptions.plist at ios/ExportOptions.plist

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="$REPO_ROOT/freezme"
IOS_DIR="$FLUTTER_DIR/ios"
ARCHIVE_PATH="$FLUTTER_DIR/build/ios/Freezme.xcarchive"
EXPORT_PATH="$FLUTTER_DIR/build/ios/ipa"

echo "── Freezme Production Build ────────────────────────────────────"

# ── 1. Ensure dependencies are fresh ──────────────────────────────
echo "1/4  Syncing dependencies..."
cd "$FLUTTER_DIR"
flutter pub get
cd "$IOS_DIR" && pod install --silent
cd "$FLUTTER_DIR"

# ── 2. Run analyzer to catch errors before building ───────────────
echo "2/4  Running static analysis..."
dart analyze lib/ --fatal-infos 2>&1 | grep -E "^(error)" || true
ERRORS=$(dart analyze lib/ 2>&1 | grep -c "^   error" || true)
if [[ "$ERRORS" -gt 0 ]]; then
  echo "❌  $ERRORS compile error(s) found. Fix before building."
  dart analyze lib/ 2>&1 | grep "^   error"
  exit 1
fi
echo "     No errors."

# ── 3. Flutter build IPA ──────────────────────────────────────────
echo "3/4  Building release IPA..."
flutter build ipa \
  --release \
  --export-options-plist="$IOS_DIR/ExportOptions.plist" \
  --build-name="$(grep '^version:' "$FLUTTER_DIR/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)" \
  --build-number="$(date +%Y%m%d%H)"

# ── 4. Confirm output ─────────────────────────────────────────────
echo "4/4  Verifying output..."
IPA=$(find "$EXPORT_PATH" -name "*.ipa" | head -1)
if [[ -z "$IPA" ]]; then
  echo "❌  IPA not found. Check Xcode signing configuration."
  exit 1
fi
SIZE=$(du -sh "$IPA" | cut -f1)
echo ""
echo "✅  Build complete: $IPA ($SIZE)"
echo "   Upload to App Store Connect via Transporter or:"
echo "   xcrun altool --upload-app -f \"$IPA\" -t ios -u <apple-id>"

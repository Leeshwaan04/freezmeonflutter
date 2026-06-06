#!/usr/bin/env bash
# build-ipa.sh — Repeatable TestFlight archive with Sentry + release tag baked in.
#
# Usage:
#   export SENTRY_DSN="https://xxxx@oyyyy.ingest.sentry.io/zzzz"
#   ./build-ipa.sh
#
# Reads the version+build from pubspec.yaml automatically so APP_RELEASE always
# matches the binary Apple receives.
set -euo pipefail

cd "$(dirname "$0")"

# Derive freezme@<version>+<build> from pubspec.yaml (e.g. freezme@1.0.0+16)
VERSION_LINE=$(grep '^version:' pubspec.yaml | awk '{print $2}')
APP_RELEASE="freezme@${VERSION_LINE}"

if [[ -z "${SENTRY_DSN:-}" ]]; then
  echo "⚠️  SENTRY_DSN is not set — building WITHOUT crash reporting."
  echo "    To include Sentry:  export SENTRY_DSN='https://...' && ./build-ipa.sh"
  echo ""
  read -r -p "Continue without Sentry? [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "Aborted."; exit 1; }
fi

echo "→ Building IPA for ${APP_RELEASE}"
echo "→ Sentry: ${SENTRY_DSN:+enabled}${SENTRY_DSN:-disabled}"

flutter build ipa --release \
  --dart-define=SENTRY_DSN="${SENTRY_DSN:-}" \
  --dart-define=APP_RELEASE="${APP_RELEASE}"

echo ""
echo "✓ Done. Open the archive to upload to App Store Connect:"
echo "    open build/ios/archive/Runner.xcarchive"
echo "  (Xcode Organizer → Distribute App → App Store Connect → Upload)"

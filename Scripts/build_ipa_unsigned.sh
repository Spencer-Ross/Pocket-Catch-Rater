#!/usr/bin/env bash
# Build an unsigned Release IPA for sideloading via LiveContainer.
# Does not require Apple provisioning profiles or App ID registration.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="Pocket Catch Rater"
APP_NAME="Pocket Catch Rater"
CONFIGURATION="${CONFIGURATION:-Release}"
OUTPUT_DIR="$ROOT/build/ipa"
IPA_PATH="$OUTPUT_DIR/PocketCatchRater-unsigned.ipa"
DERIVED_DATA="$ROOT/build/DerivedData-unsigned"

GRDB_PATH="$ROOT/SourcePackages/checkouts/GRDB.swift"
if [[ ! -d "$GRDB_PATH/.git" ]]; then
  echo "GRDB not found. Running bootstrap_packages.sh..."
  "$ROOT/Scripts/bootstrap_packages.sh"
fi

mkdir -p "$OUTPUT_DIR"
rm -rf "$DERIVED_DATA"

echo "Building unsigned $CONFIGURATION for iOS device (arm64)..."
xcodebuild \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  DEVELOPMENT_TEAM="" \
  build

APP_PATH="$DERIVED_DATA/Build/Products/${CONFIGURATION}-iphoneos/${APP_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: Expected app bundle not found at:" >&2
  echo "  $APP_PATH" >&2
  exit 1
fi

STAGING="$OUTPUT_DIR/staging"
rm -rf "$STAGING"
mkdir -p "$STAGING/Payload"
cp -R "$APP_PATH" "$STAGING/Payload/"

rm -f "$IPA_PATH"
(
  cd "$STAGING"
  zip -qr "$IPA_PATH" Payload
)
rm -rf "$STAGING"

IPA_SIZE="$(du -h "$IPA_PATH" | awk '{print $1}')"
echo ""
echo "Done."
echo "  IPA:  $IPA_PATH"
echo "  Size: $IPA_SIZE"
echo ""
echo "Import into LiveContainer:"
echo "  1. Open LiveContainer on your iPhone"
echo "  2. Tap + and select this IPA file (AirDrop, Files, etc.)"
echo "  3. If needed, enable JIT-less signing in LiveContainer Settings"
echo "     (Import Certificate from SideStore/AltStore)"

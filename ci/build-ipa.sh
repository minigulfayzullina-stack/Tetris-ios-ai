#!/usr/bin/env bash
#
# Builds the app into an .ipa on a macOS machine. Called by
# .github/workflows/ios-ipa.yml, but it can also be run by hand:
#
#   ci/build-ipa.sh
#
# Signing is automatic. If BUILD_CERTIFICATE_BASE64 and
# PROVISIONING_PROFILE_BASE64 are set the artifact is signed; otherwise the
# build is unsigned (installable only after re-signing).
#
set -euo pipefail

CONFIGURATION="${CONFIGURATION:-Release}"
EXPORT_METHOD="${EXPORT_METHOD:-development}"
TEAM_ID="${APPLE_TEAM_ID:-}"

# Always operate from the repository root.
cd "$(dirname "$0")/.."

# On CI RUNNER_TEMP is provided; locally fall back to a fresh temp directory.
WORK="${RUNNER_TEMP:-$(mktemp -d)}"
mkdir -p "$WORK"
ARCHIVE="$WORK/Tetris.xcarchive"

echo "== toolchain =="
xcodebuild -version
swift --version

echo
echo "== generating the Xcode project =="
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "   installing XcodeGen"
  brew install xcodegen
fi
xcodegen generate
xcodebuild -list -project Tetris.xcodeproj

SIGNED=false
if [ -n "${BUILD_CERTIFICATE_BASE64:-}" ] && [ -n "${PROVISIONING_PROFILE_BASE64:-}" ]; then
  SIGNED=true
fi

if [ "$SIGNED" = true ]; then
  echo
  echo "== importing the signing identity =="

  KEYCHAIN="$WORK/build.keychain-db"
  CERT="$WORK/cert.p12"
  PROFILE="$WORK/profile.mobileprovision"

  printf '%s' "$BUILD_CERTIFICATE_BASE64" | base64 -d > "$CERT"
  printf '%s' "$PROVISIONING_PROFILE_BASE64" | base64 -d > "$PROFILE"

  security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
  security set-keychain-settings -lut 21600 "$KEYCHAIN"
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"

  security import "$CERT" -k "$KEYCHAIN" \
    -P "$P12_PASSWORD" \
    -T /usr/bin/codesign -T /usr/bin/security

  security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" > /dev/null

  security list-keychain -d user -s "$KEYCHAIN" \
    $(security list-keychain -d user | tr -d '"')

  mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
  UUID=$(security cms -D -i "$PROFILE" | plutil -extract UUID raw -)
  cp "$PROFILE" ~/Library/MobileDevice/Provisioning\ Profiles/"$UUID".mobileprovision
  echo "   installed provisioning profile $UUID"
else
  echo
  echo "== no signing secrets found: building UNSIGNED =="
fi

echo
echo "== archiving =="
EXTRA=""
if [ "$SIGNED" != true ]; then
  EXTRA="CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="
fi

xcodebuild archive \
  -project Tetris.xcodeproj \
  -scheme Tetris \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  $EXTRA

echo
mkdir -p dist
rm -f dist/*.ipa

if [ "$SIGNED" = true ]; then
  echo "== exporting the signed .ipa =="
  OPTIONS="$WORK/ExportOptions.plist"
  sed -e "s/__METHOD__/${EXPORT_METHOD}/" \
      -e "s/__TEAM__/${TEAM_ID}/" \
      ci/ExportOptions.plist > "$OPTIONS"

  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$OPTIONS" \
    -exportPath "$WORK/export"

  cp "$WORK/export"/*.ipa dist/
else
  echo "== packaging an unsigned .ipa =="
  APP=$(find "$ARCHIVE/Products/Applications" -maxdepth 1 -name '*.app' | head -1)
  if [ -z "$APP" ]; then
    echo "no .app found inside the archive" >&2
    exit 1
  fi

  NAME=$(basename "$APP" .app)
  mkdir -p dist/Payload
  cp -R "$APP" dist/Payload/
  (cd dist && zip -qry "$NAME-unsigned.ipa" Payload)
  rm -rf dist/Payload

  echo "note: an unsigned .ipa must be re-signed (Sideloadly / AltStore)"
  echo "      before it will install on a stock device."
fi

echo
echo "== artifacts =="
ls -la dist/

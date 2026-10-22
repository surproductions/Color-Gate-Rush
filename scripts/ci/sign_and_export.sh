#!/usr/bin/env bash
# Archives and exports a SIGNED .ipa using credentials supplied through CI secrets.
# Required environment (set from GitHub Actions secrets, never committed):
#   IOS_CERTIFICATE_P12_BASE64   base64 of the signing certificate + private key (.p12)
#   IOS_CERTIFICATE_PASSWORD     password for the .p12
#   IOS_PROVISIONING_PROFILE_BASE64  base64 of the .mobileprovision matching the bundle ID
#   IOS_TEAM_ID                  Apple Developer Team ID
# Optional:
#   IOS_EXPORT_METHOD   ad-hoc (default) | development | app-store
#   IOS_BUNDLE_ID       overrides the bundle identifier (must match the profile)
#   BUILD_NUMBER        CFBundleVersion
set -euo pipefail
: "${IOS_CERTIFICATE_P12_BASE64:?missing}" "${IOS_CERTIFICATE_PASSWORD:?missing}"
: "${IOS_PROVISIONING_PROFILE_BASE64:?missing}" "${IOS_TEAM_ID:?missing}"
METHOD="${IOS_EXPORT_METHOD:-ad-hoc}"
BUNDLE_ID="${IOS_BUNDLE_ID:-com.surproductions.colorgaterush}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
OUTPUT="${1:?output ipa path}"
RUNNER_TMP="${RUNNER_TEMP:-$(mktemp -d)}"

KEYCHAIN="$RUNNER_TMP/signing.keychain-db"
KEYCHAIN_PASSWORD="$(uuidgen)"
CERT="$RUNNER_TMP/cert.p12"
PROFILE="$RUNNER_TMP/profile.mobileprovision"
echo "$IOS_CERTIFICATE_P12_BASE64" | base64 --decode > "$CERT"
echo "$IOS_PROVISIONING_PROFILE_BASE64" | base64 --decode > "$PROFILE"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$CERT" -P "$IOS_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN"
security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security list-keychain -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')
rm -f "$CERT"

security cms -D -i "$PROFILE" > "$RUNNER_TMP/profile.plist"
PROFILE_UUID="$(plutil -extract UUID raw "$RUNNER_TMP/profile.plist")"
PROFILE_NAME="$(plutil -extract Name raw "$RUNNER_TMP/profile.plist")"
mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "$PROFILE" "$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"
echo "Using provisioning profile: $PROFILE_NAME"

if [ "$METHOD" = "development" ]; then IDENTITY="Apple Development"; else IDENTITY="Apple Distribution"; fi

xcodebuild archive \
  -project ColorGateRush.xcodeproj -scheme ColorGateRush -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Signed.xcarchive \
  DEVELOPMENT_TEAM="$IOS_TEAM_ID" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" \
  PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN"

cat > "$RUNNER_TMP/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>$METHOD</string>
  <key>teamID</key><string>$IOS_TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>$IDENTITY</string>
  <key>provisioningProfiles</key>
  <dict><key>$BUNDLE_ID</key><string>$PROFILE_NAME</string></dict>
  <key>compileBitcode</key><false/>
  <key>stripSwiftSymbols</key><true/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive -archivePath build/Signed.xcarchive \
  -exportOptionsPlist "$RUNNER_TMP/ExportOptions.plist" -exportPath build/SignedExport
mkdir -p "$(dirname "$OUTPUT")"
mv build/SignedExport/*.ipa "$OUTPUT"
security delete-keychain "$KEYCHAIN" || true
rm -f "$PROFILE"
echo "Signed IPA written to $OUTPUT ($METHOD)"

#!/usr/bin/env bash
# Archives and exports a SIGNED .ipa using an App Store Connect API key and Xcode
# automatic ("cloud-managed") signing: Xcode creates or reuses the signing certificate and
# provisioning profile for the team, so no .p12 or .mobileprovision is needed.
#
# Required environment (from GitHub Actions secrets, never committed):
#   APPLE_TEAM_ID   Apple Developer Team ID
#   ASC_KEY_ID      App Store Connect API key ID
#   ASC_ISSUER_ID   App Store Connect issuer ID
#   ASC_KEY_P8      Contents of the AuthKey_<id>.p8 file (with or without BEGIN/END lines)
# Optional:
#   IOS_EXPORT_METHOD  app-store-connect (default) | release-testing (Ad Hoc) | debugging (Development)
#   IOS_BUNDLE_ID      bundle identifier (default com.surproductions.colorgaterush)
#   TESTFLIGHT_UPLOAD  "true" to upload to App Store Connect instead of only exporting
#   BUILD_NUMBER       CFBundleVersion
# The API key needs the Admin role: export uses Apple's cloud-managed distribution certificate.
set -euo pipefail
: "${APPLE_TEAM_ID:?missing}" "${ASC_KEY_ID:?missing}" "${ASC_ISSUER_ID:?missing}" "${ASC_KEY_P8:?missing}"
METHOD="${IOS_EXPORT_METHOD:-app-store-connect}"
BUNDLE_ID="${IOS_BUNDLE_ID:-com.surproductions.colorgaterush}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
OUTPUT="${1:?output ipa path}"
TMP="${RUNNER_TEMP:-$(mktemp -d)}"

KEY_PATH="$TMP/AuthKey_${ASC_KEY_ID}.p8"
umask 077
if printf '%s' "$ASC_KEY_P8" | grep -q "BEGIN PRIVATE KEY"; then
  printf '%s\n' "$ASC_KEY_P8" > "$KEY_PATH"
else
  # Secret stored as bare base64 body: rebuild the PEM wrapper.
  { echo "-----BEGIN PRIVATE KEY-----"
    printf '%s' "$ASC_KEY_P8" | tr -d ' \r\n' | fold -w 64
    echo
    echo "-----END PRIVATE KEY-----"; } > "$KEY_PATH"
fi
trap 'rm -f "$KEY_PATH"' EXIT

AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

# Archive WITHOUT signing. CI machines are throwaway, so a locally created development
# certificate would be orphaned after every run (Xcode then demands it be revoked). Instead the
# export step below signs for distribution with Apple's cloud-managed certificate via the API key.
xcodebuild archive \
  -project ColorGateRush.xcodeproj -scheme ColorGateRush -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Signed.xcarchive \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" CODE_SIGN_STYLE=Automatic \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

DESTINATION=export
[ "${TESTFLIGHT_UPLOAD:-false}" = "true" ] && [ "$METHOD" = "app-store-connect" ] && DESTINATION=upload

cat > "$TMP/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>$METHOD</string>
  <key>teamID</key><string>$APPLE_TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>$DESTINATION</string>
  <key>stripSwiftSymbols</key><true/>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST

# For uploads, export once locally as well so the release still gets an IPA file.
xcodebuild -exportArchive -archivePath build/Signed.xcarchive \
  -exportOptionsPlist "$TMP/ExportOptions.plist" -exportPath build/SignedExport "${AUTH[@]}"
if [ "$DESTINATION" = "upload" ]; then
  echo "Uploaded build $BUILD_NUMBER to App Store Connect (TestFlight processing follows)."
  sed -i '' 's#<string>upload</string>#<string>export</string>#' "$TMP/ExportOptions.plist"
  xcodebuild -exportArchive -archivePath build/Signed.xcarchive \
    -exportOptionsPlist "$TMP/ExportOptions.plist" -exportPath build/SignedExport "${AUTH[@]}"
fi
mkdir -p "$(dirname "$OUTPUT")"
mv build/SignedExport/*.ipa "$OUTPUT"
echo "Signed IPA written to $OUTPUT ($METHOD)"

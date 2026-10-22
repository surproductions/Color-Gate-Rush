#!/usr/bin/env bash
# Inspects an .ipa and prints a verification report. Fails if the archive is not a valid
# device (iphoneos, arm64) app bundle.
set -euo pipefail
IPA="${1:?ipa path}"
[ -s "$IPA" ] || { echo "IPA missing or empty: $IPA" >&2; exit 1; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
unzip -q "$IPA" -d "$WORK"
APP="$(find "$WORK/Payload" -maxdepth 1 -name '*.app' -print -quit)"
[ -n "$APP" ] || { echo "No Payload/*.app inside IPA" >&2; exit 1; }
PLIST="$APP/Info.plist"
EXEC="$(plutil -extract CFBundleExecutable raw "$PLIST")"
PLATFORM="$(plutil -extract DTPlatformName raw "$PLIST")"
ARCHS="$(lipo -archs "$APP/$EXEC")"

echo "== Color Door Rush IPA verification =="
echo "File:            $(basename "$IPA")"
echo "Size (bytes):    $(stat -f%z "$IPA")"
echo "SHA-256:         $(shasum -a 256 "$IPA" | awk '{print $1}')"
echo "App bundle:      $(basename "$APP")"
echo "Bundle ID:       $(plutil -extract CFBundleIdentifier raw "$PLIST")"
echo "Display name:    $(plutil -extract CFBundleDisplayName raw "$PLIST")"
echo "Version:         $(plutil -extract CFBundleShortVersionString raw "$PLIST") ($(plutil -extract CFBundleVersion raw "$PLIST"))"
echo "Minimum iOS:     $(plutil -extract MinimumOSVersion raw "$PLIST")"
echo "Platform:        $PLATFORM"
echo "SDK:             $(plutil -extract DTSDKName raw "$PLIST")"
echo "Executable arch: $ARCHS"
echo "Contents:"
unzip -l "$IPA" | awk 'NR>3 {print "  " $4}' | grep -E '^  Payload/[^/]+/[^/]*$' | head -40 || true
echo "Signature:"
if codesign -dv "$APP" >"$WORK/cs.txt" 2>&1; then
  sed 's/^/  /' "$WORK/cs.txt"
  if [ -f "$APP/embedded.mobileprovision" ]; then
    security cms -D -i "$APP/embedded.mobileprovision" > "$WORK/profile.plist"
    echo "  Provisioning profile: $(plutil -extract Name raw "$WORK/profile.plist")"
    echo "  Team: $(plutil -extract TeamName raw "$WORK/profile.plist")"
    echo "  Expires: $(plutil -extract ExpirationDate raw "$WORK/profile.plist")"
    echo "SIGNING STATUS: SIGNED"
  else
    echo "SIGNING STATUS: SIGNED (no embedded provisioning profile)"
  fi
else
  echo "  $(cat "$WORK/cs.txt")"
  echo "SIGNING STATUS: UNSIGNED - re-sign before installing on a device"
fi

[ "$PLATFORM" = "iphoneos" ] || { echo "ERROR: not a device build (platform $PLATFORM)" >&2; exit 1; }
echo "$ARCHS" | grep -q arm64 || { echo "ERROR: executable lacks arm64" >&2; exit 1; }
[ -f "$APP/Assets.car" ] || { echo "ERROR: compiled asset catalog missing" >&2; exit 1; }
echo "RESULT: valid iphoneos arm64 application archive"

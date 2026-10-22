#!/usr/bin/env bash
# Packages the .app from an unsigned device archive into an .ipa (Payload/<App>.app, zipped).
# The result is a genuine arm64 iphoneos build, but it carries no code signature: it must be
# re-signed (e.g. with your Apple ID via AltStore/Sideloadly, or with your own certificate)
# before it can be installed on a device.
set -euo pipefail
ARCHIVE="${1:?archive path}"
OUTPUT="${2:?output ipa path}"
APP_DIR="$ARCHIVE/Products/Applications"
APP="$(find "$APP_DIR" -maxdepth 1 -name '*.app' -print -quit)"
[ -n "$APP" ] || { echo "No .app found in $APP_DIR" >&2; exit 1; }
WORK="$(mktemp -d)"
mkdir -p "$WORK/Payload" "$(dirname "$OUTPUT")"
cp -R "$APP" "$WORK/Payload/"
rm -f "$OUTPUT"
OUT_ABS="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"
(cd "$WORK" && zip -qry "$OUT_ABS" Payload)
rm -rf "$WORK"
echo "Packaged $OUTPUT"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="${APP_DIR:-$DIST_DIR/Valen.app}"
ZIP_PATH="${ZIP_PATH:-$DIST_DIR/Valen-0.2.1-macos-arm64.zip}"

if [[ ! -d "$APP_DIR" ]]; then
  echo "error: app bundle not found: $APP_DIR" >&2
  echo "Run Scripts/build-app.sh first." >&2
  exit 1
fi

if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_PASSWORD:-}" ]]; then
  cat >&2 <<EOF
error: missing notarization credentials.

Set these environment variables:
  APPLE_ID             Apple ID email
  APPLE_TEAM_ID        Apple Developer Team ID
  APPLE_APP_PASSWORD   App-specific password

Example:
  APPLE_ID="you@example.com" \\
  APPLE_TEAM_ID="ABCDE12345" \\
  APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" \\
  Scripts/notarize-app.sh
EOF
  exit 1
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait

xcrun stapler staple "$APP_DIR"
spctl --assess --type execute --verbose "$APP_DIR"

echo "Notarized and stapled $APP_DIR"

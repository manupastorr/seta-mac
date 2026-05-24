#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT/dist/SetaMac.app}"
ZIP_PATH="${APP_PATH%.app}.zip"
APPLE_ID="${SETA_NOTARY_APPLE_ID:-}"
APPLE_TEAM_ID="${SETA_NOTARY_TEAM_ID:-}"
APPLE_APP_PASSWORD="${SETA_NOTARY_APP_PASSWORD:-}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH"
  exit 1
fi

if [[ -z "$APPLE_ID" || -z "$APPLE_TEAM_ID" || -z "$APPLE_APP_PASSWORD" ]]; then
  echo "Set notarization env vars first:"
  echo "  SETA_NOTARY_APPLE_ID"
  echo "  SETA_NOTARY_TEAM_ID"
  echo "  SETA_NOTARY_APP_PASSWORD"
  exit 1
fi

"$ROOT/scripts/sign-app.sh" "$APP_PATH"

echo "Zipping for notarization..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Submitting to Apple notary service..."
xcrun notarytool submit "$ZIP_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait

echo "Stapling ticket..."
xcrun stapler staple "$APP_PATH"
echo "Notarized: $APP_PATH"

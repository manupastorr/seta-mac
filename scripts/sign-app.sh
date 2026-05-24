#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT/dist/SetaMac.app}"
IDENTITY="${SETA_CODESIGN_IDENTITY:-Developer ID Application}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH"
  echo "Run ./scripts/build-app.sh first."
  exit 1
fi

if [[ "$IDENTITY" == "Developer ID Application" ]]; then
  echo "Set SETA_CODESIGN_IDENTITY to your signing certificate name."
  echo "Example: export SETA_CODESIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'"
  exit 1
fi

echo "Signing $APP_PATH with $IDENTITY"
codesign --force --deep --options runtime --sign "$IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type exec --verbose=4 "$APP_PATH" || true
echo "Signed: $APP_PATH"

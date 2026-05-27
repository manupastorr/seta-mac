#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
ZIP_NAME="SetaMac-${VERSION}-macos14.zip"
STAGE="$ROOT/dist/release"
APP_NAME="SetaMac.app"

"$ROOT/scripts/build-app.sh"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$ROOT/dist/$APP_NAME" "$STAGE/"
sed "s/see VERSION file in this folder/SetaMac ${VERSION}/" "$ROOT/INSTALL.txt" > "$STAGE/INSTALL.txt"
cp "$ROOT/LICENSE" "$ROOT/VERSION" "$STAGE/"

(
  cd "$STAGE"
  ditto -c -k --sequesterRsrc --keepParent "$APP_NAME" "../$ZIP_NAME"
)

echo "Release zip: $ROOT/dist/$ZIP_NAME"
echo "Upload: gh release create v${VERSION} dist/${ZIP_NAME} --title \"SetaMac ${VERSION}\" --notes-file CHANGELOG.md"

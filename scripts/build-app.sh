#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PRODUCT="SetaMac"
APP_NAME="SetaMac.app"
BUILD_DIR="$ROOT/.build/release"
APP_DIR="$ROOT/dist/$APP_NAME"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="${SETA_BUILD_NUMBER:-1}"

echo "Building $PRODUCT $VERSION (release)..."
swift build -c release --product "$PRODUCT"

echo "Packaging $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$PRODUCT" "$APP_DIR/Contents/MacOS/$PRODUCT"
cp "$ROOT/LICENSE" "$APP_DIR/Contents/Resources/LICENSE"

SETA_SRC="${SETA_SRC:-$ROOT/../seta}"
SCANNER_DEST="$APP_DIR/Contents/Resources/Scanner"

if [[ ! -f "$SETA_SRC/scan_library.py" ]]; then
  echo "Seta scanner not found at $SETA_SRC"
  echo "Set SETA_SRC to the seta repo path before building."
  exit 1
fi

echo "Bundling scanner from $SETA_SRC..."
mkdir -p "$SCANNER_DEST"
rsync -a \
  --exclude '.venv/' \
  --exclude 'library.json' \
  --exclude '.env' \
  --exclude '__pycache__/' \
  --exclude '.git/' \
  --exclude '.DS_Store' \
  "$SETA_SRC/" "$SCANNER_DEST/"

if [[ ! -f "$SCANNER_DEST/scan_library.py" || ! -f "$SCANNER_DEST/requirements.txt" ]]; then
  echo "Bundled scanner is incomplete at $SCANNER_DEST"
  exit 1
fi
if [[ -d "$SCANNER_DEST/.venv" ]]; then
  echo "Bundled scanner must not include .venv"
  exit 1
fi

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>SetaMac</string>
  <key>CFBundleIdentifier</key>
  <string>com.manupastorr.seta.mac</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>SetaMac</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

echo "Done: $APP_DIR ($VERSION)"
echo "Bundled scanner: $SCANNER_DEST"
echo "Open with: open \"$APP_DIR\""

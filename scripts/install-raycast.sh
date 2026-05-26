#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$ROOT/raycast"
SCRIPT="$SCRIPT_DIR/open-seta.sh"
APP="$ROOT/dist/SetaMac.app"
APP_LINK="/Applications/SetaMac.app"

chmod +x "$SCRIPT"

if [[ ! -d "$APP" ]]; then
  echo "Building SetaMac.app first..."
  "$ROOT/scripts/build-app.sh"
fi

ln -sfn "$APP" "$APP_LINK"
echo "Linked $APP_LINK -> $APP"

echo
echo "Raycast can open SetaMac immediately:"
echo "  1. Open Raycast"
echo "  2. Search: SetaMac"
echo "  3. Press Return"
echo
echo "Optional script command (one-time setup):"
echo "  1. Raycast → Settings (⌘,) → Extensions"
echo "  2. + → Add Script Directory"
echo "  3. Select: $SCRIPT_DIR"
echo "  4. Search Raycast for: Open Seta"
echo

open -a Raycast
open "$SCRIPT_DIR"

#!/usr/bin/env bash
# Capture PNG screenshots for docs/screenshots/ (GitHub does not render SVG in Markdown).
# Grant Accessibility to your terminal: System Settings → Privacy & Security → Accessibility.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/screenshots"
APP="$ROOT/dist/SetaMac.app"

if [[ ! -d "$APP" ]]; then
  "$ROOT/scripts/build-app.sh"
fi

mkdir -p "$OUT"

window_bounds() {
  osascript <<'APPLESCRIPT'
tell application "SetaMac" to activate
delay 0.3
tell application "System Events"
  tell process "SetaMac"
    set frontmost to true
    set targetWindow to window "Seta 🍄"
    set {x, y} to position of targetWindow
    set {w, h} to size of targetWindow
    return (x as text) & "," & (y as text) & "," & (w as text) & "," & (h as text)
  end tell
end tell
APPLESCRIPT
}

capture_main() {
  local bounds="$1"
  screencapture -x -R"$bounds" "$OUT/01-map.png"
  echo "Wrote $OUT/01-map.png"
}

capture_folders_sheet() {
  osascript -e 'tell application "SetaMac" to activate' \
    -e 'tell application "System Events" to tell process "SetaMac" to click menu item "Library Folders…" of menu "Library" of menu bar 1' || true
  sleep 1.2
  local bounds="$1"
  screencapture -x -R"$bounds" "$OUT/02-folders.png"
  echo "Wrote $OUT/02-folders.png"
  osascript -e 'tell application "System Events" to tell process "SetaMac" to keystroke "w" using command down' || true
}

capture_player() {
  local bounds="$1"
  IFS=',' read -r x y w h <<<"$bounds"
  local bar_h=120
  local bar_y=$((y + h - bar_h))
  screencapture -x -R"${x},${bar_y},${w},${bar_h}" "$OUT/03-player.png"
  sips -Z 1200 "$OUT/03-player.png" --out "$OUT/03-player.png" >/dev/null
  echo "Wrote $OUT/03-player.png"
}

open -a "$APP"
echo "Waiting for SetaMac…"
sleep 6

BOUNDS=$(window_bounds) || {
  echo "Could not read window bounds. Grant Accessibility to this terminal, then retry."
  exit 1
}

capture_main "$BOUNDS"
sips -Z 1400 "$OUT/01-map.png" --out "$OUT/01-map.png" >/dev/null
capture_folders_sheet "$BOUNDS"
sips -Z 1400 "$OUT/02-folders.png" --out "$OUT/02-folders.png" >/dev/null
capture_player "$BOUNDS"
echo "Done. Commit docs/screenshots/*.png and push."

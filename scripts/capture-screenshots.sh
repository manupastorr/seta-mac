#!/usr/bin/env bash
# Capture real PNG screenshots (replaces docs/screenshots/*.svg previews).
# Grant Accessibility to your terminal: System Settings → Privacy & Security → Accessibility.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/screenshots"
APP="$ROOT/dist/SetaMac.app"

if [[ ! -d "$APP" ]]; then
  "$ROOT/scripts/build-app.sh"
fi

mkdir -p "$OUT"
open -a "$APP"
echo "Waiting for SetaMac…"
sleep 6

osascript <<'APPLESCRIPT' || true
tell application "SetaMac" to activate
delay 0.5
tell application "System Events"
  tell process "SetaMac"
    set frontmost to true
    repeat 20 times
      if (count of windows) > 0 then exit repeat
      delay 0.25
    end repeat
    if (count of windows) > 0 then
      set position of window 1 to {80, 60}
      set size of window 1 to {1280, 800}
    end if
  end tell
end tell
APPLESCRIPT

capture() {
  local name="$1"
  local id
  id=$(osascript -e 'tell application "System Events" to tell process "SetaMac" to get id of window 1' 2>/dev/null) || true
  if [[ -z "$id" ]]; then
    echo "Could not get window id. Grant Accessibility to this terminal, then retry."
    exit 1
  fi
  screencapture -x -l"$id" "$OUT/${name}.png"
  echo "Wrote $OUT/${name}.png"
}

capture "01-map"
echo "→ Open Library → Library Folders… then run: $0 folders"
echo "→ Play a track, then run: $0 player"

if [[ "${1:-}" == "folders" ]]; then
  capture "02-folders"
elif [[ "${1:-}" == "player" ]]; then
  capture "03-player"
fi

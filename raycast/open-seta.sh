#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open Seta
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🍄
# @raycast.packageName Seta
# @raycast.description Open the Seta Mac BPM × intensity map app

# Documentation:
# @raycast.author Manuel Pastor Ringuelet

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/SetaMac.app"

if [[ ! -d "$APP" ]]; then
  echo "SetaMac.app not found. Build it first:"
  echo "cd \"$ROOT\" && ./scripts/build-app.sh"
  exit 1
fi

open "$APP"

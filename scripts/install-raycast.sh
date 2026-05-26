#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/raycast/open-seta.sh"

chmod +x "$SCRIPT"

echo "Raycast script ready:"
echo "  $SCRIPT"
echo
echo "Add it in Raycast:"
echo "  1. Open Raycast → Settings (⌘,) → Extensions"
echo "  2. Click + → Add Script Directory"
echo "  3. Select: $ROOT/raycast"
echo
echo "Then search Raycast for: Open Seta"

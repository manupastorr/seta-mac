#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SETA_ROOT="$(cd "$ROOT/../seta" && pwd)"

echo "== SetaMac checks =="
cd "$ROOT"
swift run SetaMacChecks

echo "== SetaMac release build =="
swift build -c release --product SetaMac

echo "== SetaMac app bundle =="
./scripts/build-app.sh

echo "== Python tests (seta) =="
cd "$SETA_ROOT"
.venv/bin/python -m unittest discover -s tests -v

echo "== Node tests (seta) =="
node --test tests/test_playback.mjs tests/test_draft.mjs tests/test_mix_links.mjs tests/test_render_safe.mjs

echo
echo "All automated verification passed."
echo "Optional manual pass: docs/native-e2e-checklist.md"
echo "Launch native app: open \"$ROOT/dist/SetaMac.app\""

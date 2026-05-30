#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SETA_ROOT="$(cd "$ROOT/../seta" && pwd)"
SWIFT_BUILD_FLAGS_ARRAY=()
if [[ -n "${SWIFT_BUILD_FLAGS:-}" ]]; then
  read -r -a SWIFT_BUILD_FLAGS_ARRAY <<< "$SWIFT_BUILD_FLAGS"
fi

echo "== SetaMac checks =="
cd "$ROOT"
swift run "${SWIFT_BUILD_FLAGS_ARRAY[@]}" SetaMacChecks

echo "== SetaMac release build =="
swift build "${SWIFT_BUILD_FLAGS_ARRAY[@]}" -c release --product SetaMac

echo "== SetaMac app bundle =="
./scripts/build-app.sh

echo "== Bundled scanner smoke =="
APP_BUNDLE="$ROOT/dist/SetaMac.app"
SCANNER="$APP_BUNDLE/Contents/Resources/Scanner"
test -d "$APP_BUNDLE"
test -f "$SCANNER/scan_library.py"
test -f "$SCANNER/requirements.txt"
test ! -e "$SCANNER/.venv"
test ! -f "$SCANNER/library.json"
test ! -f "$SCANNER/cache.json"
test ! -f "$SCANNER/scan-progress.json"
test ! -d "$SCANNER/tests"
echo "Bundled scanner files OK in $APP_BUNDLE"

echo "== Python tests (seta) =="
cd "$SETA_ROOT"
.venv/bin/python -m unittest discover -s tests -v

echo "== Node tests (seta) =="
node --test tests/test_playback.mjs tests/test_draft.mjs tests/test_mix_links.mjs tests/test_render_safe.mjs

echo
echo "All automated verification passed."
echo "Optional manual pass: docs/native-e2e-checklist.md"
echo "Launch native app: open \"$ROOT/dist/SetaMac.app\""

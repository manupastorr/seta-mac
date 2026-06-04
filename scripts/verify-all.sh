#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCANNER_ROOT="$ROOT/Scanner"
SCANNER_PYTHON="${SCANNER_PYTHON:-$SCANNER_ROOT/.venv/bin/python}"
SWIFT_BUILD_FLAGS_ARRAY=()
if [[ -n "${SWIFT_BUILD_FLAGS:-}" ]]; then
  read -r -a SWIFT_BUILD_FLAGS_ARRAY <<< "$SWIFT_BUILD_FLAGS"
fi

echo "== SetaMac checks =="
cd "$ROOT"
if ((${#SWIFT_BUILD_FLAGS_ARRAY[@]})); then
  swift run "${SWIFT_BUILD_FLAGS_ARRAY[@]}" SetaMacChecks
else
  swift run SetaMacChecks
fi

echo "== SetaMac release build =="
if ((${#SWIFT_BUILD_FLAGS_ARRAY[@]})); then
  swift build "${SWIFT_BUILD_FLAGS_ARRAY[@]}" -c release --product SetaMac
else
  swift build -c release --product SetaMac
fi

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

echo "== Python scanner tests =="
if [[ ! -x "$SCANNER_PYTHON" ]]; then
  echo "Scanner Python not found at $SCANNER_PYTHON"
  echo "Create it with: python3 -m venv Scanner/.venv && Scanner/.venv/bin/pip install -r Scanner/requirements.txt"
  exit 1
fi
PYTHONPATH="$SCANNER_ROOT" "$SCANNER_PYTHON" -m unittest discover -s "$SCANNER_ROOT/tests" -v

echo
echo "All automated verification passed."
echo "Optional manual pass: docs/native-e2e-checklist.md"
echo "Launch native app: open \"$ROOT/dist/SetaMac.app\""

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
TAG="v${VERSION}"
ZIP_NAME="SetaMac-${VERSION}-macos14.zip"
ZIP_PATH="$ROOT/dist/$ZIP_NAME"
NOTES_FILE="$ROOT/dist/release-notes-${VERSION}.md"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI not found: install or authenticate gh before publishing."
  exit 1
fi

if [[ -n "$(git status --porcelain)" && "${DRY_RUN:-}" != "1" ]]; then
  echo "Working tree is dirty. Commit release metadata before publishing."
  git status --short
  exit 1
fi

if gh release view "$TAG" >/dev/null 2>&1; then
  if [[ "${DRY_RUN:-}" == "1" ]]; then
    echo "Dry run: release $TAG already exists, so a real publish would stop here."
  else
    echo "Release $TAG already exists. Refusing to replace it."
    exit 1
  fi
fi

echo "== Verify and package $TAG =="
"$ROOT/scripts/verify-all.sh"
"$ROOT/scripts/make-release.sh"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Release zip not found: $ZIP_PATH"
  exit 1
fi

awk -v version="$VERSION" '
  $0 == "## " version { in_section = 1; next }
  in_section && /^## / { exit }
  in_section { print }
' "$ROOT/CHANGELOG.md" > "$NOTES_FILE"

if ! grep -q '[^[:space:]]' "$NOTES_FILE"; then
  echo "No changelog notes found for $VERSION."
  exit 1
fi

if [[ "${DRY_RUN:-}" == "1" ]]; then
  echo "Dry run: would publish $TAG with $ZIP_PATH"
  echo "Notes file: $NOTES_FILE"
  exit 0
fi

gh release create "$TAG" "$ZIP_PATH" --title "SetaMac $VERSION" --notes-file "$NOTES_FILE"
gh release view "$TAG" --json tagName,name,url,assets

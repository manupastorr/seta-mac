# Changelog

## 0.3.2

- Fix scary missing `library.json` error on first install; guide users to run **Rescan library** after adding folders.
- Only auto-load a library file when it actually exists.

## 0.3.1

- Stop auto-discovering the scanner at `~/Music/tracks/tools/seta`; use Application Support, bundled setup, dev sibling, or an explicitly saved scanner path.

## 0.3.0

- First-run setup: SetaMac installs its bundled scanner locally with no git or Terminal.
- Release builds bundle the scanner inside `SetaMac.app`; setup runs from the app on first launch.
- Install docs updated for the new flow: download, open, set up analysis, add folders, rescan.

## 0.2.0

- Product language: SetaMac is now framed as a local-first, map-first set-journey tool for starting DJ set drafts with candidates, bridge routes, weak-link review, and Rekordbox export.
- Map: collision-aware dot layout, zoom up to 10× toward the cursor, vector redraw while zoomed, and tighter vertical layout (measured filter-bar top chrome, intensity axis capped to library data).
- Map: trims excess top whitespace by using a tighter plot inset and balanced intensity-domain padding.
- Library Folders: multiple curated and incoming roots, recursive scan.
- Rescan passes your folder list to the Python scanner.
- Hide tracks or remove folders from Seta without deleting audio files.

## 0.1.0

- Native map-first library view, playback, draft building, candidate highlighting, and Python rescan bridge.

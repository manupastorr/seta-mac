# Changelog

## 0.3.9

- Show scanned tracks on the map in batches while **Rescan library** continues in the background.
- Add a disposable `scan-progress.json` handoff so first scans no longer look empty until completion.
- Move the production scanner source into `seta-mac/Scanner` so app releases no longer depend on a sibling `seta` checkout.
- Keep partial scan results out of release bundles and in-app scanner refreshes.
- Extend scanner/app tests for partial library contracts, progress parsing, and packaging exclusions.

## 0.3.8

- Prevent duplicate rescans and stop scans from running when no configured folder can be accessed.
- Exclude scanner cache and test artifacts from release bundles and in-app scanner refreshes.
- Make saved draft normalization more robust and avoid timestamp-based draft ID collisions.
- Avoid a possible hang when launching the Rekordbox helper fails.

## 0.3.7

- Choose scanner worker count automatically from available CPU and memory instead of forcing one worker on every Mac.
- Keep low-memory or low-core Macs on one worker for scanner stability.
- Cap automatic workers conservatively and support `SETA_SCANNER_WORKERS` for troubleshooting overrides.

## 0.3.6

- Fix scanner refresh so existing installs receive updated bundled scanner files.
- Run scanner analysis with one worker for macOS stability.
- Pin bundled Librosa below 0.11 to avoid scanner crashes during audio analysis.
- Add release checks for scanner entrypoint, explicit roots, and dependency pinning.

## 0.3.5

- Fix misleading scan ETA during cache reads; show time remaining only during actual audio analysis.

## 0.3.4

- Show live scan progress with track counts and estimated time remaining during **Rescan library**.
- Stream scanner output in real time; keep the Library folders sheet open while scanning.

## 0.3.3

- Fix **Rescan library** not writing `library.json` (bundled `scan_library.py` missing CLI entrypoint).
- Do not show tracks until library folders are configured; release builds no longer auto-load the dev sibling scanner library.
- Rescan uses only folders you pick in the app, not hidden `~/Music/tracks` defaults.

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

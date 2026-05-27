# SetaMac

Native macOS sibling project for Seta.

Reads `library.json` from the Python scanner and implements the core DJ workflow natively.

## Commands

```bash
./scripts/verify-all.sh   # Swift checks + real library smoke + release app + seta tests
./scripts/run.sh          # dev run
open dist/SetaMac.app     # after verify-all or build-app.sh
./scripts/install-raycast.sh  # add raycast/ as a Script Directory, then search "Open Seta"
```

Optional signing/notarization (requires Apple Developer credentials):

```bash
export SETA_CODESIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
./scripts/sign-app.sh

export SETA_NOTARY_APPLE_ID='you@example.com'
export SETA_NOTARY_TEAM_ID='TEAMID'
export SETA_NOTARY_APP_PASSWORD='app-specific-password'
./scripts/notarize-app.sh
```

On first launch the app auto-loads the newest available `library.json` from:
- the last opened path
- the sibling `../seta/library.json`
- `~/Music/tracks/tools/seta/library.json`

## Current Scope

- Decode/validate `library.json`
- Native track list + BPM x energy map
- Set-zone filters/overlays, Camelot, genre, source, BPM, draft-only filters
- Neighbor queue + play queue navigation
- Drafts: multiple drafts, notes, drag reorder, final marks, persistence, export
- Player dock with waveform seek, time display, keyboard shortcuts
- Effective energy parity with the web app, including local manual BPM, key, and intensity overrides
- Rescan library via the existing Python scanner (`scan_library.py`)
- Unsigned `.app` packaging plus optional sign/notarize scripts
- Manual native E2E checklist

## Verification

```bash
swift run SetaMacChecks
swift build --product SetaMac
./scripts/verify-all.sh
```

Manual checklist: [docs/native-e2e-checklist.md](docs/native-e2e-checklist.md)

Expected launch state:
- The app auto-loads `library.json` when available.
- The map renders immediately.
- The player dock starts idle with `Nothing playing`; playback should start only after selecting/playing a track.
- Selecting a track and opening the mix dock shows BPM, Key, and Intensity controls; the override persists locally and each can be cleared with `Auto`.

## Intentionally Still Python

- Audio analysis (`analyze.py`) stays in the Python scanner until golden parity tests exist.
- Use **Library → Rescan Library** in the app or `./start.sh --quick` in `../seta`.
- Manual track overrides are local `UserDefaults` state (`seta-track-overrides-v1`), not edits to `library.json`.

## Local Swift Toolchain Note

This machine's Swift CLI does not expose `XCTest`/`Testing` to SwiftPM test targets, so checks run through `swift run SetaMacChecks`.

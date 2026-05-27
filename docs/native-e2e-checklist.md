# SetaMac Native E2E Checklist

Date: 2026-05-24

Run after `./scripts/verify-all.sh` passes.

## Setup

```bash
cd ../seta
./start.sh --quick

cd ../seta-mac
./scripts/build-app.sh && open dist/SetaMac.app
```

## Core Workflow

- [ ] App auto-loads `library.json` when available.
- [ ] Player dock starts idle with `Nothing playing`; no track auto-plays on launch.
- [ ] Toolbar open/rescan works.
- [ ] Search, source, genre, BPM, Camelot, draft-only, and set-zone filters work.
- [ ] Map selection, neighbor highlighting, and explore-link overlay work.
- [ ] Selecting a track shows the mix-dock Intensity slider; changing it moves/sorts the track by the manual value.
- [ ] Clicking `Auto` clears the manual intensity override and returns to scanner energy.
- [ ] Player dock plays local audio, seeks via waveform, and shows elapsed/total time.
- [ ] Top filter bar does not wrap chip labels or clip Reset/open/rescan controls at the default window width.
- [ ] In windowed mode the filter bar uses icon buttons with tooltips and sits flush under the title bar.
- [ ] Set-zone overlays are visible but do not overpower track dots.

## Keyboard / Menu

- [ ] Space play/pause
- [ ] ← / → previous/next
- [ ] Shift ← / → seek ±10s
- [ ] `n` neighbor queue, `a` add draft, `p` play draft, `e`/`b` draft sort, `z` zones panel, `?` help
- [ ] Typing shortcut letters in search or note fields enters text and does not trigger shortcuts.
- [ ] Command-Control-F toggles native full screen.

## Window / Map Interaction

- [ ] At the minimum window size, the top bar and player are not cut off.
- [ ] At full screen, clicking a node selects and plays the track.
- [ ] After zooming the map, clicking a visible node still selects and plays the track.
- [ ] When zoomed in without the loupe, hovering a node scales it up with an accent ring.
- [ ] Starting zoom while the loupe is visible hides the loupe immediately.

## Draft

- [ ] Multiple drafts can be created/selected/deleted.
- [ ] Notes, final marks, drag reorder, persistence after restart.
- [ ] M3U/text export.

## Scanner Bridge

- [ ] Rescan Library runs Python `scan_library.py` and reloads `library.json`.

## Optional Release

- [ ] `./scripts/sign-app.sh` with `SETA_CODESIGN_IDENTITY`
- [ ] `./scripts/notarize-app.sh` with Apple notary env vars

## Regression

```bash
swift run SetaMacChecks
./scripts/verify-all.sh
```

## Tooling Note

Computer Use can inspect the SetaMac window state, but click automation was unreliable during the latest pass. Treat this checklist as manual unless native UI automation is added later.

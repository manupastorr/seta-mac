# SetaMac Native E2E Checklist

Date: 2026-05-24

SetaMac should feel like a map-first set-journey tool: start from a seed track, explore plausible candidates and bridges, build a draft, review weak links, then export without turning the workflow into automatic playlist generation.

Run after `./scripts/verify-all.sh` passes.

## Setup

```bash
cd ../seta
./start.sh --quick

cd ../seta-mac
./scripts/build-app.sh && open dist/SetaMac.app
```

## Library folders

- [ ] First launch (no folders configured) opens **Library Folders…**.
- [ ] Add multiple Library and Incoming folders; subfolders appear after rescan.
- [ ] Remove a folder from the list; rescan drops its tracks from the map.
- [ ] **Remove from Seta…** on a neighbor row hides the track without deleting the file.
- [ ] Hidden tracks can be restored from **Library Folders…**, then rescan.

## Core Workflow

- [ ] App auto-loads `library.json` when available.
- [ ] Player dock starts idle with `Nothing playing`; no track auto-plays on launch.
- [ ] Toolbar open/rescan works.
- [ ] Search, source, genre, BPM, Camelot, draft-only, and set-zone filters work.
- [ ] Map selection and candidate highlighting work.
- [ ] Candidate reasons explain practical fit, such as key, BPM move, energy direction, outro-to-intro fit, zone, or review warnings.
- [ ] Candidate kinds feel meaningful: smooth, lift, bridge, contrast, and risky should not read as fake confidence.
- [ ] Selecting a track shows BPM, Key, and Intensity controls in the mix dock; each `Auto` button clears that manual override.
- [ ] Player dock plays local audio, seeks via waveform, and shows elapsed/total time.
- [ ] Top filter bar does not wrap chip labels or clip Reset/open/rescan controls at the default window width.
- [ ] In windowed mode the filter bar uses icon buttons with tooltips and sits flush under the title bar.
- [ ] Set-zone overlays are visible but do not overpower track dots.

## Keyboard / Menu

- [ ] Space play/pause
- [ ] ← / → previous/next
- [ ] Shift ← / → seek ±10s
- [ ] `n` candidate queue, `a` add draft, `p` play draft, `e`/`b` draft sort, `z` zones panel, `?` help
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
- [ ] Draft analysis marks links to review without creating noisy anxiety.
- [ ] Bridge/repair suggestions remain opt-in and do not mutate the draft until applied.
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

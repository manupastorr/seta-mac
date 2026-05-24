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
- [ ] Player dock plays local audio, seeks via waveform, and shows elapsed/total time.
- [ ] Top filter bar does not wrap chip labels or clip Reset/open/rescan controls at the default window width.
- [ ] Set-zone overlays are visible but do not overpower track dots.

## Keyboard / Menu

- [ ] Space play/pause
- [ ] ← / → previous/next
- [ ] Shift ← / → seek ±10s
- [ ] `n` neighbor queue, `a` add draft, `p` play draft, `e`/`b` draft sort, `z` zones panel, `?` help

## Draft

- [ ] Multiple drafts can be created/selected/deleted.
- [ ] Notes, final marks, drag reorder, persistence after restart.
- [ ] M3U/text export.

## Scanner Bridge

- [ ] Rescan Library runs Python `scan_library.py` and reloads `library.json`.
- [ ] Rescan With Mix Edges rebuilds `edges`.

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

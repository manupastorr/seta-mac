# SetaMac

Local-first macOS app for building DJ set drafts from a map of your library.

Start from a seed track, explore smart candidates and bridge routes, repair weak links, then export the draft to Rekordbox or another DJ tool. Seta keeps the early creative phase map-first, so you can shape a set journey before committing to a fixed playlist order.

**[Download & install](docs/DOWNLOAD.md)** · [Releases](https://github.com/manupastorr/seta-mac/releases) · License: [MIT](LICENSE)

![SetaMac demo](docs/media/setamac-demo.gif)

## Quick install

1. Download `SetaMac-0.3.10-macos14.zip` from [Releases](https://github.com/manupastorr/seta-mac/releases).
2. Unzip it and move **SetaMac.app** to Applications.
3. **Open it:** right-click **SetaMac.app** → **Open** → **Open**.  
   macOS says **“damaged”**? Click **Cancel**, then follow [these steps](docs/DOWNLOAD.md#if-macos-blocks-the-app) (one Terminal line).
4. **In the app:** click **Start setup** and wait (internet once).
5. Add music folders in **Library → Library Folders…**, then click **Rescan library**. Tracks appear in batches while analysis continues.

![SetaMac map-first set journey view](docs/screenshots/01-map-overview.png)

More detail: **[docs/DOWNLOAD.md](docs/DOWNLOAD.md)**

## Why this exists

SetaMac is a personal project for exploring local-first music workflow tooling. It is built as a practical desktop tool, not a SaaS product.

Technically, it combines a Swift macOS app, a bundled Python scanner, music-library analysis, Rekordbox export/import support, and a small release packaging and validation flow.

## Usage notes

- Bundled scanner analyzes folders you choose; SetaMac does not move or rename your files.
- During a scan, SetaMac shows analyzed tracks as partial results; the completed `library.json` is written at the end.
- Manual BPM/key/energy overrides stay in local app settings.
- Removing a folder or track inside SetaMac does not delete audio files.

## Technical overview

- `Sources/SetaMacCore` contains domain logic, library models, scoring, drafts, scanner setup, and Rekordbox import/export support.
- `Sources/SetaMacApp` contains the macOS UI.
- `Sources/SetaMacChecks` contains smoke and validation checks for the app core.
- `Scanner/` contains the production Python audio/library scanner bundled into app releases.
- `scripts/verify-all.sh` is the main local verification command. It builds Swift targets, packages the app, checks the bundled scanner contents, and runs scanner unit tests.
- Generated scanner state such as `Scanner/library.json`, `Scanner/cache.json`, `Scanner/scan-progress.json`, and `Scanner/scan.log` is ignored and is not bundled.

## Development

```bash
swift build
swift run SetaMacChecks
./scripts/verify-all.sh
```

Release convention: bump `VERSION`, add a matching `CHANGELOG.md` section, commit those metadata updates, then run `./scripts/release-github.sh`.

# SetaMac

Local-first macOS app for building DJ set drafts from a map of your library.

Start from a seed track, explore smart candidates and bridge routes, repair weak links, then export the draft to Rekordbox or another DJ tool. Seta keeps the early creative phase map-first, so you can shape a set journey before committing to a fixed playlist order.

**[Download & install](docs/DOWNLOAD.md)** · [Releases](https://github.com/manupastorr/seta-mac/releases) · Scanner: [seta](https://github.com/manupastorr/seta) · License: [MIT](LICENSE)

![SetaMac demo](docs/media/setamac-demo.gif)

## Quick install

1. Download `SetaMac-0.2.0-macos14.zip` from [Releases](https://github.com/manupastorr/seta-mac/releases).
2. Unzip it and move **SetaMac.app** to Applications.
3. First launch: right-click **SetaMac.app** → **Open**.
4. In SetaMac: **Library → Library Folders…** → add your music folders.
5. For **Rescan library**, install the scanner once:

```bash
git clone https://github.com/manupastorr/seta.git
cd seta
./start.sh
```

![SetaMac map-first set journey view](docs/screenshots/01-map-overview.png)

Full install guide and screenshots: **[docs/DOWNLOAD.md](docs/DOWNLOAD.md)**.

## Versioning

- App version: `VERSION` (also in the app bundle and release zip name).
- Changelog: [CHANGELOG.md](CHANGELOG.md).

```bash
# Maintainer: bump VERSION, update CHANGELOG, then:
./scripts/make-release.sh
gh release create v0.2.0 dist/SetaMac-0.2.0-macos14.zip --title "SetaMac 0.2.0" --notes-file CHANGELOG.md
```

## Develop

```bash
./scripts/verify-all.sh
./scripts/run.sh
open dist/SetaMac.app
```

Optional signing: `./scripts/sign-app.sh` and `./scripts/notarize-app.sh` (Apple Developer account).

## Notes

- Reads `library.json` from the Python scanner; does not move or rename your files.
- Manual BPM/key/energy overrides stay in local app settings, not in `library.json`.
- Removing a folder or track inside SetaMac does not delete audio files.

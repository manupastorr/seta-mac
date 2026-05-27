# Download SetaMac

Local-first macOS app for building DJ set drafts from a map of your library. Start with one track, explore smart candidates and bridges, then export a draft to Rekordbox or another DJ tool. It works with folders on your Mac; nothing is uploaded.

**Latest release:** [SetaMac 0.2.0](https://github.com/manupastorr/seta-mac/releases/tag/v0.2.0) — download `SetaMac-0.2.0-macos14.zip`.

| Requirement | Detail |
|-------------|--------|
| macOS | 14+ |
| Scanner | [seta](https://github.com/manupastorr/seta) (Python, for **Rescan**) |
| Music files | `.wav`, `.aiff`, `.flac`, `.mp3` in folders you add |

![SetaMac demo](media/setamac-demo.gif)

## Install

1. Download `SetaMac-0.2.0-macos14.zip` from [Releases](https://github.com/manupastorr/seta-mac/releases/tag/v0.2.0).
2. Unzip and move **SetaMac.app** to Applications.
3. First launch: right-click **SetaMac.app** → **Open** → **Open**.
4. Install the scanner once if you want to use **Rescan library**:

```bash
git clone https://github.com/manupastorr/seta.git
cd seta
./start.sh
```

5. In SetaMac: **Library → Library Folders…** → add your music folders.
6. Click **Rescan library** after adding or changing folders.

Removing a folder or track in SetaMac does **not** delete your audio files.

## Screenshots

| Set journey map | Mix candidates |
|--------------|----------------|
| ![Map-first set journey view](screenshots/01-map-overview.png) | ![Mix candidates and Camelot wheel](screenshots/02-mix-candidates.png) |

Re-capture: `./scripts/capture-screenshots.sh` (Terminal needs Accessibility in System Settings).

## Optional: sign & notarize

For distribution without the right-click **Open** step, use an Apple Developer account and `./scripts/sign-app.sh` + `./scripts/notarize-app.sh` (see [README](../README.md)).

## License

MIT — see [LICENSE](../LICENSE).

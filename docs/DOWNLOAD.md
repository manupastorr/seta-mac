# Download SetaMac

Native macOS app for browsing a DJ library on a **BPM × energy** map. Works with your own folders on your Mac — nothing is uploaded.

**Latest release:** [GitHub Releases](https://github.com/manupastorr/seta-mac/releases) — download `SetaMac-<version>-macos14.zip`.

| Requirement | Detail |
|-------------|--------|
| macOS | 14+ |
| Scanner | [seta](https://github.com/manupastorr/seta) (Python, for **Rescan**) |
| Audio | `.wav`, `.aiff`, `.flac`, `.mp3` in folders you add |

## Install

1. Download the zip from [Releases](https://github.com/manupastorr/seta-mac/releases).
2. Unzip and move **SetaMac.app** to Applications.
3. **First launch:** right-click the app → **Open** → **Open** (unsigned build; macOS will warn once).
4. Clone the scanner once:

```bash
git clone https://github.com/manupastorr/seta.git
cd seta && ./start.sh
```

5. In SetaMac: **Library → Library Folders…** → add **Library** (curated) and **Incoming** (intake) folders → **Rescan library**.

Removing a folder or track in Seta does **not** delete your audio files.

## Screenshots

| Map | Library folders | Player |
|-----|-----------------|--------|
| ![BPM × energy map](screenshots/01-map.svg) | ![Folder setup](screenshots/02-folders.svg) | ![Player dock](screenshots/03-player.svg) |

Replace with real captures anytime: `./scripts/capture-screenshots.sh` (needs Accessibility permission for your terminal).

## Optional: sign & notarize

For distribution without the right-click **Open** step, use an Apple Developer account and `./scripts/sign-app.sh` + `./scripts/notarize-app.sh` (see [README](../README.md)).

## License

MIT — see [LICENSE](../LICENSE).

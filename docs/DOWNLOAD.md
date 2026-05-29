# Download SetaMac

Local-first macOS app for building DJ set drafts from a map of your library. Start with one track, explore smart candidates and bridges, then export a draft to Rekordbox or another DJ tool. It works with folders on your Mac; nothing is uploaded.

**Latest release:** [SetaMac 0.3.1](https://github.com/manupastorr/seta-mac/releases/tag/v0.3.1) — download `SetaMac-0.3.1-macos14.zip`.

| Requirement | Detail |
|-------------|--------|
| macOS | 14+ |
| Internet | Once, during first-time setup |
| Music files | `.wav`, `.aiff`, `.flac`, `.mp3` in folders you add |

![SetaMac demo](media/setamac-demo.gif)

## Before you start

- Have your music already in folders on your Mac.
- Allow about 10 minutes for the first launch.
- macOS may ask you to confirm SetaMac is safe to open — that is normal for apps outside the App Store.

## Install

1. Download `SetaMac-0.3.1-macos14.zip` from [Releases](https://github.com/manupastorr/seta-mac/releases/tag/v0.3.1).
2. Unzip and move **SetaMac.app** to Applications.
3. First launch: right-click **SetaMac.app** → **Open** → **Open**.
4. In SetaMac, click **Start setup** when asked. Keep the app open until setup finishes (a few minutes; internet required once).
5. Click **Continue**, then add your music folders in **Library → Library Folders…**.
6. Click **Rescan library** after adding or changing folders.

Removing a folder or track in SetaMac does **not** delete your audio files.

## Troubleshooting

| Problem | What to do |
|---------|------------|
| “App can’t be opened” | Right-click **SetaMac.app** → **Open** → **Open** again. |
| Setup failed | Check internet, click **Try again**, or restart SetaMac. |
| Empty map / **Rescan** disabled | Finish setup first, then add folders in **Library Folders…**. |
| Scan failed | Confirm the folder was added and try **Rescan library** again. |

## Developer install (optional)

If you prefer the standalone Python scanner repo instead of the in-app setup:

```bash
git clone https://github.com/manupastorr/seta.git
cd seta
./start.sh
```

Keep the scanner repo anywhere you like and point SetaMac at it only if you configure that path explicitly after the first scan.

## Screenshots

| Set journey map | Mix candidates |
|--------------|----------------|
| ![Map-first set journey view](screenshots/01-map-overview.png) | ![Mix candidates and Camelot wheel](screenshots/02-mix-candidates.png) |

## License

MIT — see [LICENSE](../LICENSE).

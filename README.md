# SetaMac

Local-first macOS app for building DJ set drafts from a map of your library.

Start from a seed track, explore smart candidates and bridge routes, repair weak links, then export the draft to Rekordbox or another DJ tool. Seta keeps the early creative phase map-first, so you can shape a set journey before committing to a fixed playlist order.

**[Download & install](docs/DOWNLOAD.md)** · [Releases](https://github.com/manupastorr/seta-mac/releases) · License: [MIT](LICENSE)

![SetaMac demo](docs/media/setamac-demo.gif)

## Quick install

1. Download `SetaMac-0.3.2-macos14.zip` from [Releases](https://github.com/manupastorr/seta-mac/releases).
2. Unzip it and move **SetaMac.app** to Applications.
3. **Open it:** right-click **SetaMac.app** → **Open** → **Open**.  
   macOS says **“damaged”**? Click **Cancel**, then follow [these steps](docs/DOWNLOAD.md#if-macos-blocks-the-app) (one Terminal line).
4. **In the app:** click **Start setup** and wait (internet once).
5. Add music folders in **Library → Library Folders…**, then click **Rescan library** (this creates `library.json`).

![SetaMac map-first set journey view](docs/screenshots/01-map-overview.png)

More detail: **[docs/DOWNLOAD.md](docs/DOWNLOAD.md)**

## Notes

- Bundled scanner analyzes folders you choose; SetaMac does not move or rename your files.
- Manual BPM/key/energy overrides stay in local app settings.
- Removing a folder or track inside SetaMac does not delete audio files.

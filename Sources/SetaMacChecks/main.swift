import Foundation
import SetaMacCore

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

func decodeLibraryFixture(_ json: String) throws -> SetaLibrary {
    try SetaLibrary.decode(from: Data(json.utf8))
}

func routesReuseScoredEdges(_ routes: [SmartBridgeRoute]) -> Bool {
    routes.allSatisfy { route in
        let pairs = Array(zip(route.tracks, route.tracks.dropFirst()))
        guard route.transitions.count == pairs.count else { return false }
        return pairs.enumerated().allSatisfy { index, pair in
            route.transitions[index] == SmartMixEngine.score(
                from: pair.0,
                to: pair.1,
                intent: JourneyIntent(mode: .bridge)
            )
        }
    }
}

// MARK: - Library contract checks

func decodesCurrentLibraryContract() throws {
    let json = """
    {
      "generated_at": "2026-05-23T00:00:00+00:00",
      "tracks_root": "/tracks",
      "curate_root": "/curate",
      "track_count": 2,
      "tracks": [
        {
          "id": "a",
          "path": "/tracks/Artist - One.wav",
          "artist": "Artist",
          "title": "One",
          "source": "tracks",
          "genre": "House",
          "batch": null,
          "duration_sec": 300.0,
          "bpm": 128.0,
          "bpm_raw": 128.0,
          "bpm_octave_corrected": false,
          "bpm_source": "tag",
          "bpm_confidence": 0.8,
          "key": "8A",
          "energy": 0.7,
          "vocals": "unclear",
          "vocals_confidence": 0.4,
          "analysis_error": null,
          "waveform_version": 1,
          "waveform_peak": [0.1, 0.2],
          "waveform_low": [0.1, 0.2],
          "waveform_mid": [0.1, 0.2],
          "waveform_high": [0.1, 0.2]
        },
        {
          "id": "b",
          "path": "/tracks/Artist - Two.wav",
          "artist": "Artist",
          "title": "Two",
          "source": "to_curate",
          "genre": "Batch",
          "batch": "Batch",
          "duration_sec": 301.0,
          "bpm": 129.0,
          "bpm_raw": 129.0,
          "bpm_octave_corrected": false,
          "bpm_source": "analysis",
          "bpm_confidence": 0.6,
          "key": "8A",
          "energy": 0.75,
          "vocals": "no",
          "vocals_confidence": 0.7,
          "analysis_error": null
        }
      ],
      "edges": [
        { "source": "a", "target": "b", "score": 0.9 }
      ]
    }
    """

    let library = try decodeLibraryFixture(json)
    check(library.trackCount == 2, "track count decodes")
    check(library.tracks[0].displayTitle == "One", "display title decodes")
    check(library.tracks[0].waveformPeak?.count == 2, "waveform decodes")
    check(library.edges.first?.score == 0.9, "edge score decodes")
    check(library.validationIssues().isEmpty, "valid fixture has no issues")
}

func validationFindsContractIssues() throws {
    let json = """
    {
      "track_count": 3,
      "tracks": [
        { "id": "a", "path": "/x.wav", "source": "bad", "bpm": 181.0, "energy": 1.2 },
        { "id": "a", "path": "/y.wav", "source": "tracks", "waveform_peak": [0.1], "waveform_low": [0.1, 0.2] }
      ],
      "edges": [
        { "source": "a", "target": "missing", "score": 1.2 }
      ]
    }
    """

    let issues = try decodeLibraryFixture(json).validationIssues()
    check(issues.contains { $0.contains("track_count") }, "detects count mismatch")
    check(issues.contains { $0.contains("duplicate track id") }, "detects duplicate id")
    check(issues.contains { $0.contains("unexpected source") }, "detects source issue")
    check(issues.contains { $0.contains("energy out of range") }, "detects energy issue")
    check(issues.contains { $0.contains("bpm out of map range") }, "detects bpm issue")
    check(issues.contains { $0.contains("waveform arrays") }, "detects waveform shape issue")
    check(issues.contains { $0.contains("edge target not found") }, "detects missing edge target")
    check(issues.contains { $0.contains("edge score out of range") }, "detects edge score issue")
}

func duplicateTrackIDsCanBeSanitizedForDisplay() throws {
    let json = """
    {
      "track_count": 3,
      "tracks": [
        { "id": "a", "path": "/tracks/Artist - One.wav", "source": "tracks", "bpm": 128.0, "key": "8A" },
        { "id": "a", "path": "/tracks/Artist - Duplicate.wav", "source": "tracks", "bpm": 129.0, "key": "8A" },
        { "id": "b", "path": "/tracks/Artist - Two.wav", "source": "tracks", "bpm": 130.0, "key": "9A" }
      ],
      "edges": [
        { "source": "a", "target": "b", "score": 0.8 },
        { "source": "a", "target": "missing", "score": 0.8 }
      ]
    }
    """

    let library = try decodeLibraryFixture(json)
    check(library.validationIssues().contains { $0.contains("duplicate track id") }, "duplicate id remains reported")

    let displayLibrary = library.removingDuplicateTrackIDs()
    check(displayLibrary.trackCount == 2, "duplicate removal updates display track count")
    check(displayLibrary.tracks.map(\.id) == ["a", "b"], "duplicate removal keeps first track id occurrence")
    check(displayLibrary.edges.count == 1, "duplicate removal drops edges to missing ids")

    let lookup = Dictionary(uniqueKeysWithValues: displayLibrary.tracks.map { ($0.id, $0) })
    check(lookup.count == 2, "display tracks can build unique id lookup")
}

func camelotParityValues() {
    check(Camelot.compatible("8A", "8A") == 1, "same key")
    check(Camelot.compatible("8A", "8B") == 0.82, "relative major/minor")
    check(Camelot.compatible("8A", "9A") == 0.72, "adjacent same mode")
    check(Camelot.compatible("8A", "9B") == 0.55, "adjacent different mode")
    check(Camelot.compatible("8A", "10A") == 0, "incompatible key")
    check(Camelot.bpmCompatible(128, 130) == 0.9, "bpm close")
    check(Camelot.bpmCompatible(nil, 130) == 0.35, "missing bpm")
    check(Camelot.mixScore(keyA: "8A", keyB: "8A", bpmA: 128, bpmB: 128) == 1, "mix score")
    check(Camelot.colorHex("8A") == "#00838F", "color")
    check(Camelot.colorHex(nil) == "#555770", "unknown color")
}

// MARK: - Core model checks

func filterAndDraftHelpers() throws {
    let json = """
    {
      "track_count": 3,
      "tracks": [
        { "id": "low", "path": "/low.wav", "artist": "A", "title": "Low", "source": "tracks", "genre": "Organic", "bpm": 95, "energy": 0.2, "key": "8A" },
        { "id": "mid", "path": "/mid.wav", "artist": "B", "title": "Middle", "source": "to_curate", "genre": "House", "bpm": 124, "energy": 0.5, "key": "8B" },
        { "id": "high", "path": "/high.wav", "artist": "C", "title": "High", "source": "tracks", "genre": "Techno", "bpm": 140, "energy": 0.9, "key": "10A" }
      ],
      "edges": []
    }
    """
    let library = try decodeLibraryFixture(json)

    let house = library.filteredTracks(using: LibraryFilter(query: "house"))
    check(house.map(\.id) == ["mid"], "query filter")

    let trackSource = library.filteredTracks(using: LibraryFilter(sources: ["tracks"]))
    check(trackSource.map(\.id) == ["low", "high"], "source filter")

    let keyFilter = library.filteredTracks(using: LibraryFilter(keys: ["8A", "8B"]))
    check(keyFilter.map(\.id) == ["low", "mid"], "key filter")

    let draftOnly = library.filteredTracks(
        using: LibraryFilter(draftOnly: true),
        draftTrackIds: ["high"]
    )
    check(draftOnly.map(\.id) == ["high"], "draft-only filter")

    var draft = SetaDraft()
    draft.add(trackId: "high")
    draft.add(trackId: "low")
    draft.add(trackId: "high")
    draft.toggleFinal(trackId: "low")
    draft.setNote("opener", for: "low")

    check(draft.trackIds == ["high", "low"], "draft dedupes tracks")
    check(draft.resolvedTracks(from: library.tracks).map(\.id) == ["low", "high"], "draft energy sort")
    check(draft.exportM3U(from: library.tracks).contains("/low.wav"), "m3u export")
    check(draft.exportText(from: library.tracks).contains("* A - Low"), "text export final mark")

    draft.remove(trackId: "low")
    check(!draft.finalIds.contains("low"), "remove clears final")
    check(draft.notes["low"] == nil, "remove clears note")
}

func playbackHelpers() throws {
    let json = """
    {
      "track_count": 5,
      "tracks": [
        { "id": "amalv", "path": "/a.wav", "artist": "A", "title": "Amalv", "source": "tracks", "bpm": 112, "energy": 0.5, "key": "1A" },
        { "id": "n1", "path": "/n1.wav", "artist": "A", "title": "Neighbor One", "source": "tracks", "bpm": 113, "energy": 0.5, "key": "1A" },
        { "id": "n2", "path": "/n2.wav", "artist": "A", "title": "Neighbor Two", "source": "tracks", "bpm": 114, "energy": 0.5, "key": "2A" },
        { "id": "n3", "path": "/n3.wav", "artist": "A", "title": "Neighbor Three", "source": "tracks", "bpm": 111, "energy": 0.5, "key": "12A" },
        { "id": "other", "path": "/o.wav", "artist": "A", "title": "Outside", "source": "tracks", "bpm": 140, "energy": 0.5, "key": "10A" }
      ],
      "edges": []
    }
    """
    let library = try decodeLibraryFixture(json)
    let filtered = library.tracks

    let queue = Playback.buildNavigableTracks(
        filtered: filtered,
        selection: Playback.PlaybackSelection(
            highlightNeighbors: true,
            neighborQueueAnchor: "amalv"
        )
    )
    check(queue.count == 4, "neighbor queue length")
    check(queue.first?.id == "amalv", "anchor first")

    var state = Playback.PlayQueueState(selectedId: "amalv")
    _ = Playback.syncPlayQueueState(
        &state,
        filtered: filtered,
        selection: Playback.PlaybackSelection(
            highlightNeighbors: true,
            neighborQueueAnchor: "amalv"
        )
    )
    let next = Playback.nextPlayIndex(
        queue: state.playQueue,
        currentId: state.playQueue[state.playIndex].id,
        currentIndex: state.playIndex,
        step: 1
    )
    check(next != state.playIndex, "next index advances")

    let low = library.tracks.first { $0.id == "n3" }!
    let high = library.tracks.first { $0.id == "other" }!
    let draftQueue = Playback.buildNavigableTracks(
        filtered: [low, high],
        selection: Playback.PlaybackSelection(
            draftPlayMode: true,
            draftTrackIds: ["other", "n3"],
            draftSortMode: .energy
        )
    )
    check(draftQueue.map(\.id) == ["n3", "other"], "draft play queue uses sort mode")
}

func draftStoreRoundtrip() {
    var store = DraftStoreState()
    var draft = DraftStore.createDraft(name: "Fusion")
    draft.add(trackId: "x")
    draft.add(trackId: "y")
    draft.toggleFinal(trackId: "x")
    draft.setNote("opener", for: "x")
    DraftStore.upsertActiveDraft(&store, draft: draft)

    let defaults = UserDefaults(suiteName: "seta-mac-checks")!
    defaults.removePersistentDomain(forName: "seta-mac-checks")
    DraftStore.save(store, to: defaults)
    let loaded = DraftStore.load(from: defaults)
    check(loaded.activeId == draft.id, "active draft id roundtrips")
    check(loaded.drafts[draft.id]?.trackIds == ["x", "y"], "draft tracks roundtrip")
    check(loaded.drafts[draft.id]?.finalIds == ["x"], "final ids roundtrip")
    check(loaded.drafts[draft.id]?.notes["x"] == "opener", "notes roundtrip")
}

// MARK: - Settings and geometry checks

func setMomentsAndSettingsHelpers() throws {
    let json = """
    {
      "track_count": 2,
      "tracks": [
        { "id": "warm", "path": "/warm.wav", "artist": "A", "title": "Warm", "source": "tracks", "bpm": 100, "energy": 0.2, "key": "8A" },
        { "id": "peak", "path": "/peak.wav", "artist": "B", "title": "Peak", "source": "tracks", "bpm": 130, "energy": 0.8, "key": "10A" }
      ],
      "edges": [
        { "source": "warm", "target": "peak", "score": 0.4 }
      ]
    }
    """
    let library = try decodeLibraryFixture(json)
    let warm = library.tracks[0]
    check(SetMoments.matchesAnyActiveMoments(warm, activeMomentIDs: ["warmup"]), "warm track matches warmup zone")

    let warmupOnly = library.filteredTracks(using: LibraryFilter(moments: ["warmup"]))
    check(warmupOnly.map(\.id) == ["warm"], "moment filter")

    var draft = SetaDraft(trackIds: ["warm", "peak"])
    draft.reorderTrackIds(["peak", "warm"])
    check(draft.trackIds == ["peak", "warm"], "draft reorder")

    let defaults = UserDefaults(suiteName: "seta-mac-settings-check")!
    defaults.removePersistentDomain(forName: "seta-mac-settings-check")
    let settings = AppSettings(lastLibraryPath: "/tmp/library.json")
    AppSettings.save(settings, to: defaults)
    check(AppSettings.load(from: defaults).lastLibraryPath == "/tmp/library.json", "settings roundtrip")
}

func librarySourcesChecks() {
    let args = LibraryScannerArguments.build(
        quick: true,
        tracksRoots: ["/tracks/a", "/tracks/b"],
        curateRoots: ["/incoming"],
        excludedPaths: ["/tracks/a/hide.wav"]
    )
    check(args.contains("--skip-edges"), "scanner args quick")
    check(args.contains("--explicit-roots"), "scanner args explicit roots")
    check(args.filter { $0 == "--tracks-root" }.count == 2, "scanner args tracks roots")
    check(args.contains("--curate-root"), "scanner args curate root")
    check(args.contains("--exclude-path"), "scanner args exclude path")

    let defaults = UserDefaults(suiteName: "seta-mac-folder-settings-check")!
    defaults.removePersistentDomain(forName: "seta-mac-folder-settings-check")
    let folderSettings = AppSettings(
        tracksFolders: [LibraryFolderEntry(path: "/tmp/tracks")],
        curateFolders: [LibraryFolderEntry(path: "/tmp/incoming")]
    )
    AppSettings.save(folderSettings, to: defaults)
    let loaded = AppSettings.load(from: defaults)
    check(loaded.tracksFolders.count == 1, "folder settings tracks")
    check(loaded.curateFolders.count == 1, "folder settings curate")
    check(loaded.hasConfiguredFolders, "folder settings configured")

    var excluded: Set<String> = ["/a.wav"]
    ExcludedTracksStorage.save(excluded, to: defaults)
    excluded = ExcludedTracksStorage.load(from: defaults)
    check(excluded == ["/a.wav"], "excluded tracks roundtrip")
}

func decodesLibraryRootArrays() throws {
    let json = """
    {
      "generated_at": "2026-01-01T00:00:00+00:00",
      "tracks_root": "/tracks",
      "curate_root": "/curate",
      "tracks_roots": ["/tracks", "/more/tracks"],
      "curate_roots": ["/curate", "/incoming"],
      "track_count": 1,
      "tracks": [
        { "id": "a", "path": "/tracks/A.wav", "artist": "A", "title": "One", "source": "tracks", "genre": "House", "batch": null, "bpm": 124, "energy": 0.5, "key": "8A" }
      ],
      "edges": []
    }
    """
    let library = try decodeLibraryFixture(json)
    check(library.tracksRoots?.count == 2, "tracks_roots decodes")
    check(library.curateRoots?.count == 2, "curate_roots decodes")
}

func uiGeometryChecks() throws {
    let layout = MapPlotLayout(
        canvasSize: CGSize(width: 1200, height: 800),
        mixDockWidth: 278,
        rightChrome: 214,
        bottomChrome: 82,
        energyDomain: 0.2 ... 1.0
    )
    check(layout.plotWidth <= 1200 - 278 - 64 - 36 - 214, "plot width reserves right chrome")
    check(layout.bpmX(70) < layout.bpmX(180), "bpm scale increases left to right")
    check(layout.energyY(1) < layout.energyY(0), "energy scale increases bottom to top")

    let json = """
    {
      "track_count": 2,
      "tracks": [
        { "id": "t1", "path": "/x.wav", "artist": "A", "title": "T", "source": "tracks", "bpm": 124, "energy": 0.55, "key": "8A", "duration_sec": 240 },
        { "id": "t2", "path": "/y.wav", "artist": "B", "title": "U", "source": "tracks", "bpm": 126, "energy": 0.75, "key": "8B", "duration_sec": 200 }
      ],
      "edges": []
    }
    """
    let library = try decodeLibraryFixture(json)
    let track = library.tracks[0]
    let resolved = layout.resolveDisplayPositions(for: library.tracks)
    let pointA = layout.trackPoint(for: track, displayPositions: resolved)
    let pointB = layout.trackPoint(for: track, displayPositions: resolved)
    check(pointA == pointB, "display layout is deterministic")

    if library.tracks.count >= 2 {
        let t1 = library.tracks[0]
        let t2 = library.tracks[1]
        let p1 = layout.trackPoint(for: t1, displayPositions: resolved)
        let p2 = layout.trackPoint(for: t2, displayPositions: resolved)
        let minSep = TrackPresentation.nodeRadius(for: t1) + TrackPresentation.nodeRadius(for: t2) + 0.5
        check(hypot(p1.x - p2.x, p1.y - p2.y) >= minSep, "collision layout separates nearby tracks")
    }

    let segments = CamelotWheelGeometry.segments()
    check(segments.count == 24, "camelot wheel has 24 segments")
    check(segments.contains { $0.code == "8A" }, "wheel includes 8A")
    check(CamelotWheelGeometry.labelColorHex(for: "#00838F") == "#ffffff", "dark key label is white")

    let ramp = EnergyRamp.geometry(tracks: library.tracks)
    check(ramp.points.count == 2, "energy ramp points")
    check(ramp.path.hasPrefix("M"), "energy ramp path")

    let badges = TrackPresentation.badges(for: track)
    check(badges.first?.kind == .bpm, "track badges include bpm")
    check(TrackPresentation.nodeRadius(for: track, hovered: true) > TrackPresentation.nodeRadius(for: track), "hover radius boost")
    check(
        TrackPresentation.zoomHoveredNodeRadius(for: track) > TrackPresentation.nodeRadius(for: track),
        "zoom hover radius boost"
    )

    let domain = MapPlotLayout.computeEnergyDisplayDomain(tracks: library.tracks)
    check(domain.upperBound < 1, "energy display domain caps below full scale for small library")
    check(domain.upperBound >= 0.75, "energy display domain includes top track energy")

    let clusteredEnergyJSON = """
    {
      "track_count": 3,
      "tracks": [
        { "id": "warm", "path": "/warm.wav", "artist": "A", "title": "Warm", "source": "tracks", "bpm": 118, "energy": 0.68, "key": "7A" },
        { "id": "drive", "path": "/drive.wav", "artist": "B", "title": "Drive", "source": "tracks", "bpm": 124, "energy": 0.76, "key": "8A" },
        { "id": "peak", "path": "/peak.wav", "artist": "C", "title": "Peak", "source": "tracks", "bpm": 130, "energy": 0.88, "key": "9A" }
      ],
      "edges": []
    }
    """
    let clusteredLibrary = try decodeLibraryFixture(clusteredEnergyJSON)
    let clusteredDomain = MapPlotLayout.computeEnergyDisplayDomain(tracks: clusteredLibrary.tracks)
    check(clusteredDomain.upperBound <= 0.95, "clustered energy domain does not waste top space")

    let outlierTracks = (0 ..< 30).map { index in
        let energy = index == 29 ? 1.0 : 0.72 + Double(index % 8) * 0.015
        return String(
            format: #"{"id":"o%d","path":"/o%d.wav","source":"tracks","bpm":%d,"energy":%.3f}"#,
            index,
            index,
            110 + index,
            energy
        )
    }.joined(separator: ",")
    let outlierJSON = #"{"track_count":30,"tracks":[\#(outlierTracks)],"edges":[]}"#
    let outlierLibrary = try decodeLibraryFixture(outlierJSON)
    let outlierDomain = MapPlotLayout.computeEnergyDisplayDomain(tracks: outlierLibrary.tracks)
    check(outlierDomain.upperBound < 0.95, "large library ignores sparse top-energy outliers")

    let withTopChrome = MapPlotLayout(
        canvasSize: CGSize(width: 1200, height: 800),
        topChrome: 74,
        bottomChrome: 82
    )
    let withoutTopChrome = MapPlotLayout(canvasSize: CGSize(width: 1200, height: 800), bottomChrome: 82)
    check(withTopChrome.plotHeight < withoutTopChrome.plotHeight, "top chrome shrinks plot height")
    check(withTopChrome.plotOrigin(in: CGSize(width: 1200, height: 800)).y > withoutTopChrome.plotOrigin(in: CGSize(width: 1200, height: 800)).y, "top chrome lowers plot origin")
}

func smokeRealLibrary() throws {
    let envPath = ProcessInfo.processInfo.environment["SETA_LIBRARY_PATH"]
    var candidates: [URL] = []
    if let envPath {
        candidates.append(URL(fileURLWithPath: envPath))
    }
    candidates.append(contentsOf: AppSettings.defaultLibraryCandidates())

    guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
        print("SetaMacLibrarySmoke: skipped (no library.json found)")
        return
    }

    let started = Date()
    let data = try Data(contentsOf: url)
    let library = try SetaLibrary.decode(from: data)
    let decodeMs = Int(Date().timeIntervalSince(started) * 1000)

    check(library.trackCount == library.tracks.count, "real library track_count matches")
    check(!library.tracks.isEmpty, "real library has tracks")

    let filtered = library.filteredTracks(using: LibraryFilter())
    check(!filtered.isEmpty, "default filter keeps tracks")

    let withBPMKey = library.tracks.first { $0.bpm != nil && $0.key != nil }
    if let anchor = withBPMKey {
        let neighbors = Playback.mixNeighbors(trackId: anchor.id, tracks: filtered)
        check(neighbors.ids.contains(anchor.id), "real neighbor anchor included")
    }

    var draft = SetaDraft()
    for track in library.tracks.prefix(3) {
        draft.add(trackId: track.id)
    }
    check(draft.exportM3U(from: library.tracks).contains("#EXTM3U"), "real draft m3u export")
    check(!draft.exportText(from: library.tracks).isEmpty, "real draft text export")

    let waveformTrack = library.tracks.first {
        ($0.waveformPeak?.count ?? 0) > 0
    }
    check(waveformTrack != nil, "real library includes waveform data")

    print("SetaMacLibrarySmoke: OK (\(library.tracks.count) tracks, decode \(decodeMs)ms, \(url.path))")
}

// MARK: - Import and smart journey checks

func rekordboxPlaylistImport() throws {
    check(
        RekordboxPlaylistImport.normalizedPath("file://localhost/Users/me/track.wav") == "/Users/me/track.wav",
        "file url path"
    )

    let m3u = """
    #EXTM3U
    #EXTINF:-1,Artist - One
    /tracks/Artist - One.wav
    /missing/Artist - Ghost.wav
    """
    let m3uURL = FileManager.default.temporaryDirectory.appendingPathComponent("seta-test.m3u")
    try m3u.write(to: m3uURL, atomically: true, encoding: .utf8)
    let parsed = try RekordboxPlaylistImport.parseM3U(at: m3uURL)
    check(parsed.paths.count == 2, "m3u paths")

    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <DJ_PLAYLISTS Version="1.0.0">
      <COLLECTION Entries="2">
        <TRACK TrackID="1" Location="file://localhost/tracks/Artist%20-%20One.wav"/>
        <TRACK TrackID="2" Location="file://localhost/tracks/Artist%20-%20Two.wav"/>
      </COLLECTION>
      <PLAYLISTS>
        <NODE Type="0" Name="ROOT">
          <NODE Type="1" Name="Warmup">
            <TRACK Key="1"/>
            <TRACK Key="2"/>
          </NODE>
        </NODE>
      </PLAYLISTS>
    </DJ_PLAYLISTS>
    """
    let xmlURL = FileManager.default.temporaryDirectory.appendingPathComponent("seta-test.xml")
    try xml.write(to: xmlURL, atomically: true, encoding: .utf8)
    let playlists = try RekordboxPlaylistImport.parseRekordboxXML(at: xmlURL)
    check(playlists.count == 1 && playlists[0].name == "Warmup", "xml playlist")

    let libraryJSON = """
    {
      "track_count": 2,
      "tracks": [
        { "id": "one", "path": "/tracks/Artist - One.wav", "artist": "A", "title": "One", "source": "tracks" },
        { "id": "two", "path": "/tracks/Artist - Two.wav", "artist": "A", "title": "Two", "source": "tracks" }
      ],
      "edges": []
    }
    """
    let library = try decodeLibraryFixture(libraryJSON)
    let match = RekordboxPlaylistImport.matchPaths(playlists[0].paths + ["/nope.wav"], in: library.tracks)
    check(match.matchedTrackIds == ["one", "two"], "path match order")
    check(match.skippedCount == 1, "path skip missing")

    let orderJSON = """
    {
      "track_count": 3,
      "tracks": [
        { "id": "c", "path": "/c.wav", "artist": "A", "title": "C", "source": "tracks" },
        { "id": "a", "path": "/a.wav", "artist": "A", "title": "A", "source": "tracks" },
        { "id": "b", "path": "/b.wav", "artist": "A", "title": "B", "source": "tracks" }
      ],
      "edges": []
    }
    """
    let orderLibrary = try decodeLibraryFixture(orderJSON)
    let ordered = RekordboxPlaylistImport.matchPaths(
        ["/c.wav", "/a.wav", "/b.wav"],
        in: orderLibrary.tracks
    )
    check(ordered.matchedTrackIds == ["c", "a", "b"], "import preserves playlist order")

    let polluted = Data("{}".utf8) + Data("""
    {"playlists":[{"name":"Warmup","paths":["/tracks/Artist - One.wav"]}]}
    """.utf8)
    check(RekordboxLibraryBridge.playlistCount(inProcessOutput: polluted) == 1, "polluted stdout json")
}

func trackOverrideHelpers() throws {
    let json = """
    {
      "track_count": 1,
      "tracks": [
        { "id": "t1", "path": "/t.wav", "artist": "A", "title": "T", "source": "tracks", "bpm": 120, "energy": 0.4, "key": "8A" }
      ],
      "edges": []
    }
    """
    let track = try decodeLibraryFixture(json).tracks[0]
    let override = TrackOverride.normalized(bpm: 126, key: "9A", energy: 0.75)
    let updated = track.applyingTrackOverride(override)
    check(updated.bpm == 126, "override bpm")
    check(updated.key == "9A", "override key")
    check(abs(updated.effectiveEnergy - 0.75) < 0.001, "override energy")

    let badges = TrackPresentation.badges(for: updated, override: override)
    check(badges.contains { $0.text.contains("126 BPM M") }, "manual bpm badge")
    check(badges.contains { $0.text == "9A M" }, "manual key badge")

    let defaults = UserDefaults(suiteName: "seta-track-overrides-check")!
    defaults.removePersistentDomain(forName: "seta-track-overrides-check")
    defaults.set(["legacy": 0.66], forKey: TrackOverridesStorage.legacyEnergyKey)
    let migrated = TrackOverridesStorage.load(from: defaults)
    check(migrated["legacy"]?.energy == 0.66, "legacy energy migration")
    check(defaults.data(forKey: TrackOverridesStorage.storageKey) != nil, "legacy energy migrates forward")

    let clearedBpm = track.applyingTrackOverride(TrackOverride(bpm: 126, energy: 0.75))
    check(clearedBpm.bpm == 126, "bpm override applies")
    let afterClearBpm = track.applyingTrackOverride(TrackOverride(energy: 0.75))
    check(afterClearBpm.bpm == 120, "reapply from base after clearing bpm override")
    check(afterClearBpm.key == "8A", "base key unchanged when only energy overridden")
}

func smartJourneyChecks() throws {
    let json = """
    {
      "track_count": 10,
      "tracks": [
        { "id": "anchor", "path": "/a.wav", "artist": "A", "title": "Anchor", "source": "tracks", "genre": "House", "bpm": 124, "energy": 0.50, "energy_intro": 0.48, "energy_outro": 0.52, "key": "8A", "vocals": "no", "vocals_confidence": 0.8 },
        { "id": "same", "path": "/same.wav", "artist": "B", "title": "Same", "source": "tracks", "genre": "House", "bpm": 125, "energy": 0.58, "energy_intro": 0.53, "energy_outro": 0.60, "key": "8A", "vocals": "no", "vocals_confidence": 0.8 },
        { "id": "weak", "path": "/weak.wav", "artist": "C", "title": "Weak", "source": "tracks", "genre": "Techno", "bpm": 132, "energy": 0.84, "key": "10A", "vocals": "no", "vocals_confidence": 0.8 },
        { "id": "lift", "path": "/lift.wav", "artist": "D", "title": "Lift", "source": "tracks", "genre": "House", "bpm": 126, "energy": 0.64, "energy_intro": 0.55, "key": "8A", "vocals": "no", "vocals_confidence": 0.8 },
        { "id": "genreonly", "path": "/genre.wav", "artist": "D", "title": "Genre Only", "source": "tracks", "genre": "Deep House", "bpm": 124, "energy": 0.52, "energy_intro": 0.52, "key": "8A", "vocals": "no", "vocals_confidence": 0.8 },
        { "id": "truebridge", "path": "/bridge.wav", "artist": "D", "title": "True Bridge", "source": "to_curate", "genre": "Techno", "bpm": 128, "energy": 0.54, "energy_intro": 0.53, "key": "9A", "vocals": "no", "vocals_confidence": 0.8 },
        { "id": "midbridge", "path": "/mid.wav", "artist": "D", "title": "Mid Bridge", "source": "tracks", "genre": "House", "bpm": 128, "energy": 0.70, "energy_intro": 0.62, "key": "9A", "vocals": "no", "vocals_confidence": 0.8 },
        { "id": "vocal", "path": "/vocal.wav", "artist": "E", "title": "Vocal", "source": "tracks", "genre": "House", "bpm": 125, "energy": 0.56, "key": "8A", "vocals": "yes", "vocals_confidence": 0.9 },
        { "id": "vocal2", "path": "/vocal2.wav", "artist": "F", "title": "Vocal Two", "source": "tracks", "genre": "House", "bpm": 126, "energy": 0.58, "key": "8A", "vocals": "yes", "vocals_confidence": 0.9 },
        { "id": "missing", "path": "/missing.wav", "artist": "G", "title": "Missing", "source": "tracks", "genre": "House", "energy": 0.58 }
      ],
      "edges": []
    }
    """
    let tracks = try decodeLibraryFixture(json).tracks
    let byId = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
    let anchor = byId["anchor"]!
    let same = byId["same"]!
    let weak = byId["weak"]!
    let lift = byId["lift"]!
    let genreOnly = byId["genreonly"]!
    let trueBridge = byId["truebridge"]!
    let vocal = byId["vocal"]!
    let vocal2 = byId["vocal2"]!

    let strongScore = SmartMixEngine.score(from: anchor, to: same)
    let weakScore = SmartMixEngine.score(from: anchor, to: weak)
    check(strongScore.total > weakScore.total, "smart score ranks close same-key candidate higher")
    check(strongScore.reasons.contains("same key"), "smart score explains same key")

    let liftScore = SmartMixEngine.score(from: anchor, to: lift, intent: JourneyIntent(mode: .lift))
    check(liftScore.kind == .lift, "lift intent classifies controlled lift")
    check(SmartMixEngine.score(from: anchor, to: genreOnly).kind != .bridge, "genre-only difference is not labeled bridge")
    check(SmartMixEngine.score(from: anchor, to: trueBridge).kind == .bridge, "bridge label requires meaningful movement")

    let vocalScore = SmartMixEngine.score(from: vocal, to: vocal2)
    check(vocalScore.warnings.contains("vocal risk"), "vocal clash warning")
    check(!SmartMixEngine.score(from: anchor, to: vocal).warnings.contains("vocal risk"), "instrumental to vocal is not vocal clash")

    let feedback = [
        TransitionFeedback.key(from: "anchor", to: "weak"): TransitionFeedback(fromTrackID: "anchor", toTrackID: "weak", rating: 2)
    ]
    let improved = SmartMixEngine.score(from: anchor, to: weak, feedback: feedback)
    check(improved.total > weakScore.total, "feedback improves reranking")

    let feedbackURL = FileManager.default.temporaryDirectory.appendingPathComponent("seta-feedback-check.json")
    let duplicateFeedback = [
        TransitionFeedback(fromTrackID: "anchor", toTrackID: "same", rating: -2, updatedAt: 1),
        TransitionFeedback(fromTrackID: "anchor", toTrackID: "same", rating: 2, updatedAt: 2)
    ]
    let feedbackData = try JSONEncoder().encode(duplicateFeedback)
    try feedbackData.write(to: feedbackURL, options: [.atomic])
    let loadedFeedback = TransitionFeedbackStorage.load(from: feedbackURL)
    check(loadedFeedback[TransitionFeedback.key(from: "anchor", to: "same")]?.rating == 2, "feedback load tolerates duplicates")

    let neighbors = SmartMixEngine.neighbors(for: "anchor", in: tracks)
    check(neighbors.first?.track.id == "same" || neighbors.first?.track.id == "lift", "smart neighbors prefer plausible candidates")
    check(!neighbors.contains { $0.track.id == "missing" }, "missing bpm/key excluded from default neighbors")

    let routes = SmartMixEngine.bridgeRoutes(from: "anchor", to: "weak", in: tracks)
    check(routes.allSatisfy { Set($0.tracks.map(\.id)).count == $0.tracks.count }, "bridge routes do not repeat tracks")
    check(routes.count <= SmartMixEngine.bridgeRouteLimit, "bridge route limit")
    check(routesReuseScoredEdges(routes), "bridge route transitions reuse scored edges")

    var draft = SetaDraft(trackIds: ["anchor", "weak"], sortMode: .manual)
    let weakLinks = SmartMixEngine.draftWeakLinks(draft: draft, tracks: tracks)
    check(weakLinks.count == 1, "draft analyzer flags weak link")
    check(weakLinks[0].suggestions.contains { $0.kind == .insertBridge }, "draft analyzer suggests insert bridge")

    draft.reorderTrackIds(["anchor", "same"])
    check(SmartMixEngine.draftWeakLinks(draft: draft, tracks: tracks).isEmpty, "draft analyzer leaves strong link alone")
}

func scannerPathsChecks() throws {
    let fileManager = FileManager.default
    let tempRoot = fileManager.temporaryDirectory.appendingPathComponent("seta-mac-scanner-paths-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    defer {
        try? fileManager.removeItem(at: tempRoot)
    }

    let appSupport = tempRoot
        .appendingPathComponent("Library/Application Support/SetaMac/scanner", isDirectory: true)
    try fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
    fileManager.createFile(atPath: appSupport.appendingPathComponent("scan_library.py").path, contents: Data())
    fileManager.createFile(atPath: appSupport.appendingPathComponent("library.json").path, contents: Data("{}".utf8))

    let configuredRoot = tempRoot.appendingPathComponent("configured-scanner", isDirectory: true)
    try fileManager.createDirectory(at: configuredRoot, withIntermediateDirectories: true)
    fileManager.createFile(atPath: configuredRoot.appendingPathComponent("scan_library.py").path, contents: Data())

    let legacy = tempRoot.appendingPathComponent("Music/tracks/tools/seta", isDirectory: true)
    try fileManager.createDirectory(at: legacy, withIntermediateDirectories: true)
    fileManager.createFile(atPath: legacy.appendingPathComponent("scan_library.py").path, contents: Data())

    let homeOverride = tempRoot
    let appSupportRoot = ScannerPaths.applicationSupportScannerRoot(
        homeDirectory: homeOverride,
        fileManager: fileManager
    )
    check(appSupportRoot.path.hasSuffix("Library/Application Support/SetaMac/scanner"), "application support scanner path")

    let settings = AppSettings(setaScannerRoot: configuredRoot.path)
    let preferred = ScannerPaths.preferredScannerRoot(
        settings: settings,
        homeDirectory: homeOverride,
        fileManager: fileManager
    )
    check(preferred?.path == configuredRoot.path, "configured scanner root wins")

    let fallbackSettings = AppSettings()
    let fallbackPreferred = ScannerPaths.preferredScannerRoot(
        settings: fallbackSettings,
        homeDirectory: homeOverride,
        fileManager: fileManager
    )
    check(fallbackPreferred?.path == appSupport.path, "application support scanner root is preferred fallback")

    let otherHome = tempRoot.appendingPathComponent("other-home", isDirectory: true)
    let legacyOnly = otherHome.appendingPathComponent("Music/tracks/tools/seta", isDirectory: true)
    try fileManager.createDirectory(at: legacyOnly, withIntermediateDirectories: true)
    fileManager.createFile(atPath: legacyOnly.appendingPathComponent("scan_library.py").path, contents: Data())
    check(
        ScannerPaths.preferredScannerRoot(
            settings: AppSettings(),
            homeDirectory: otherHome,
            fileManager: fileManager
        ) == nil,
        "legacy scanner path is not auto-discovered"
    )

    let readyRoot = tempRoot.appendingPathComponent("ready-scanner", isDirectory: true)
    try fileManager.createDirectory(at: readyRoot, withIntermediateDirectories: true)
    fileManager.createFile(atPath: readyRoot.appendingPathComponent("scan_library.py").path, contents: Data())
    let python = readyRoot.appendingPathComponent(".venv/bin", isDirectory: true)
    try fileManager.createDirectory(at: python, withIntermediateDirectories: true)
    fileManager.createFile(atPath: python.appendingPathComponent("python").path, contents: Data())
    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: python.appendingPathComponent("python").path)
    check(ScannerPaths.isScannerReady(at: readyRoot, fileManager: fileManager), "scanner ready requires venv python")
    check(!ScannerPaths.isScannerReady(at: appSupport, fileManager: fileManager), "scanner without venv is not ready")

    let candidates = ScannerPaths.defaultLibraryCandidates(
        settings: fallbackSettings,
        homeDirectory: homeOverride,
        fileManager: fileManager
    )
    check(candidates.isEmpty, "library candidates skip scanner library without configured folders")

    let configuredFolderSettings = AppSettings(
        tracksFolders: [LibraryFolderEntry(path: "/tmp/tracks")]
    )
    let candidatesWithFolders = ScannerPaths.defaultLibraryCandidates(
        settings: configuredFolderSettings,
        homeDirectory: homeOverride,
        fileManager: fileManager
    )
    check(
        candidatesWithFolders.contains(ScannerPaths.libraryJSON(at: appSupport)),
        "library candidates include app support scanner when folders are configured"
    )
    check(!candidatesWithFolders.contains(ScannerPaths.libraryJSON(at: legacy)), "library candidates skip legacy scanner path")

    check(
        !ScannerPaths.needsInAppSetup(
            settings: AppSettings(setaScannerRoot: readyRoot.path),
            homeDirectory: homeOverride,
            fileManager: fileManager
        ),
        "in-app setup not needed when configured scanner is ready"
    )

    let devSibling = tempRoot.appendingPathComponent("seta", isDirectory: true)
    try fileManager.createDirectory(at: devSibling, withIntermediateDirectories: true)
    fileManager.createFile(atPath: devSibling.appendingPathComponent("scan_library.py").path, contents: Data())
    let devSourceFile = tempRoot
        .appendingPathComponent("seta-mac/Sources/SetaMacApp/SetaMacApp.swift", isDirectory: false)
    try fileManager.createDirectory(at: devSourceFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    fileManager.createFile(atPath: devSourceFile.path, contents: Data())
    check(
        ScannerPaths.needsInAppSetup(
            settings: fallbackSettings,
            devSiblingSourceFilePath: devSourceFile.path,
            homeDirectory: homeOverride,
            fileManager: fileManager
        ),
        "in-app setup needed when install source exists but scanner is not ready"
    )
}

func scannerInstallerChecks() throws {
    let fileManager = FileManager.default
    let tempRoot = fileManager.temporaryDirectory.appendingPathComponent("seta-mac-scanner-installer-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    defer {
        try? fileManager.removeItem(at: tempRoot)
    }

    let bundled = tempRoot.appendingPathComponent("bundled", isDirectory: true)
    let destination = tempRoot.appendingPathComponent("destination", isDirectory: true)
    let ignored = bundled.appendingPathComponent(".venv/bin", isDirectory: true)
    try fileManager.createDirectory(at: ignored, withIntermediateDirectories: true)
    fileManager.createFile(atPath: ignored.appendingPathComponent("python").path, contents: Data())
    fileManager.createFile(atPath: bundled.appendingPathComponent("scan_library.py").path, contents: Data("print('ok')".utf8))
    fileManager.createFile(atPath: bundled.appendingPathComponent("requirements.txt").path, contents: Data())
    fileManager.createFile(atPath: bundled.appendingPathComponent("library.json").path, contents: Data("{}".utf8))

    try ScannerInstaller.syncScannerFiles(from: bundled, to: destination, fileManager: fileManager)
    check(fileManager.fileExists(atPath: destination.appendingPathComponent("scan_library.py").path), "installer sync copies scanner script")
    check(fileManager.fileExists(atPath: destination.appendingPathComponent("requirements.txt").path), "installer sync copies requirements")
    check(!fileManager.fileExists(atPath: destination.appendingPathComponent("library.json").path), "installer sync skips library.json")
    check(!fileManager.fileExists(atPath: destination.appendingPathComponent(".venv/bin/python").path), "installer sync skips bundled venv")

    check(ScannerInstaller.needsInstall(destinationRoot: destination, fileManager: fileManager), "installer needed without venv")

    let missingBundle = ScannerInstaller.install(
        bundledRoot: tempRoot.appendingPathComponent("missing"),
        destinationRoot: destination
    )
    check(!missingBundle.success, "installer fails when bundled scanner is missing")

    let missingPython = ScannerInstaller.install(
        bundledRoot: bundled,
        destinationRoot: destination.appendingPathComponent("no-python", isDirectory: true),
        python3Executable: URL(fileURLWithPath: "/tmp/seta-mac-missing-python")
    )
    check(!missingPython.success, "installer fails when python3 is unavailable")
    check(missingPython.message.localizedCaseInsensitiveContains("python"), "installer reports missing python")

    let readyRoot = tempRoot.appendingPathComponent("ready", isDirectory: true)
    try fileManager.createDirectory(at: readyRoot, withIntermediateDirectories: true)
    fileManager.createFile(atPath: readyRoot.appendingPathComponent("scan_library.py").path, contents: Data())
    let readyPython = readyRoot.appendingPathComponent(".venv/bin", isDirectory: true)
    try fileManager.createDirectory(at: readyPython, withIntermediateDirectories: true)
    fileManager.createFile(atPath: readyPython.appendingPathComponent("python").path, contents: Data())
    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readyPython.appendingPathComponent("python").path)
    let alreadyReady = ScannerInstaller.install(
        bundledRoot: bundled,
        destinationRoot: readyRoot
    )
    check(alreadyReady.success, "installer skips work when scanner is already ready")

    var phases: [ScannerInstallerPhase] = []
    if let python3 = ScannerInstaller.systemPython3(fileManager: fileManager) {
        let installDestination = tempRoot.appendingPathComponent("installed", isDirectory: true)
        let installed = ScannerInstaller.install(
            bundledRoot: bundled,
            destinationRoot: installDestination,
            python3Executable: python3,
            phaseHandler: { phases.append($0) }
        )
        check(installed.success, "installer completes with system python3")
        check(ScannerPaths.isScannerReady(at: installDestination, fileManager: fileManager), "installer leaves scanner ready")
        check(phases.first == .preparing, "installer reports preparing phase")
        check(phases.last == .finished, "installer reports finished phase")
    } else {
        print("ScannerInstaller: skipped full install (python3 not found)")
    }
}

func bundledScannerReleaseChecks() {
    guard let bundlePath = ProcessInfo.processInfo.environment["SETA_APP_BUNDLE"] else {
        print("BundledScannerRelease: skipped (SETA_APP_BUNDLE not set)")
        return
    }

    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: bundlePath),
          let bundle = Bundle(path: bundlePath) else {
        check(false, "release app bundle exists at SETA_APP_BUNDLE")
        return
    }

    guard let scannerRoot = ScannerPaths.bundledScannerRoot(bundle: bundle, fileManager: fileManager) else {
        check(false, "release bundle exposes bundled scanner")
        return
    }

    check(
        fileManager.fileExists(atPath: scannerRoot.appendingPathComponent("scan_library.py").path),
        "release bundle includes scan_library.py"
    )
    check(
        fileManager.fileExists(atPath: scannerRoot.appendingPathComponent("requirements.txt").path),
        "release bundle includes requirements.txt"
    )
    check(
        !fileManager.fileExists(atPath: scannerRoot.appendingPathComponent(".venv").path),
        "release bundle excludes .venv"
    )
    check(
        !fileManager.fileExists(atPath: scannerRoot.appendingPathComponent("library.json").path),
        "release bundle excludes library.json"
    )
    if let scriptData = try? Data(contentsOf: scannerRoot.appendingPathComponent("scan_library.py")),
       let script = String(data: scriptData, encoding: .utf8) {
        check(script.contains("if __name__ == \"__main__\":"), "scan_library.py exposes CLI entrypoint")
    } else {
        check(false, "scan_library.py is readable in release bundle")
    }
}

do {
    try decodesCurrentLibraryContract()
    try validationFindsContractIssues()
    try duplicateTrackIDsCanBeSanitizedForDisplay()
    camelotParityValues()
    try filterAndDraftHelpers()
    try playbackHelpers()
    draftStoreRoundtrip()
    try setMomentsAndSettingsHelpers()
    librarySourcesChecks()
    try decodesLibraryRootArrays()
    try uiGeometryChecks()
    try rekordboxPlaylistImport()
    try trackOverrideHelpers()
    try smartJourneyChecks()
    try scannerPathsChecks()
    try scannerInstallerChecks()
    bundledScannerReleaseChecks()
    try smokeRealLibrary()
    print("SetaMacChecks: OK")
} catch {
    fputs("FAIL: \(error)\n", stderr)
    exit(1)
}

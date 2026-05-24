import Foundation
import SetaMacCore

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

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

    let library = try SetaLibrary.decode(from: Data(json.utf8))
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

    let issues = try SetaLibrary.decode(from: Data(json.utf8)).validationIssues()
    check(issues.contains { $0.contains("track_count") }, "detects count mismatch")
    check(issues.contains { $0.contains("duplicate track id") }, "detects duplicate id")
    check(issues.contains { $0.contains("unexpected source") }, "detects source issue")
    check(issues.contains { $0.contains("energy out of range") }, "detects energy issue")
    check(issues.contains { $0.contains("bpm out of map range") }, "detects bpm issue")
    check(issues.contains { $0.contains("waveform arrays") }, "detects waveform shape issue")
    check(issues.contains { $0.contains("edge target not found") }, "detects missing edge target")
    check(issues.contains { $0.contains("edge score out of range") }, "detects edge score issue")
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
    let library = try SetaLibrary.decode(from: Data(json.utf8))

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
    let library = try SetaLibrary.decode(from: Data(json.utf8))
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
    let library = try SetaLibrary.decode(from: Data(json.utf8))
    let warm = library.tracks[0]
    check(SetMoments.matchesAnyActiveMoments(warm, activeMomentIDs: ["warmup"]), "warm track matches warmup zone")

    let warmupOnly = library.filteredTracks(using: LibraryFilter(moments: ["warmup"]))
    check(warmupOnly.map(\.id) == ["warm"], "moment filter")

    let byID = Dictionary(uniqueKeysWithValues: library.tracks.map { ($0.id, $0) })
    let links = library.exploreLinks(for: "warm", tracksByID: byID)
    check(links.count == 1 && links[0].0.id == "peak", "explore links")

    var draft = SetaDraft(trackIds: ["warm", "peak"])
    draft.reorderTrackIds(["peak", "warm"])
    check(draft.trackIds == ["peak", "warm"], "draft reorder")

    let defaults = UserDefaults(suiteName: "seta-mac-settings-check")!
    defaults.removePersistentDomain(forName: "seta-mac-settings-check")
    let settings = AppSettings(lastLibraryPath: "/tmp/library.json")
    AppSettings.save(settings, to: defaults)
    check(AppSettings.load(from: defaults).lastLibraryPath == "/tmp/library.json", "settings roundtrip")
}

func uiGeometryChecks() throws {
    let layout = MapPlotLayout(
        canvasSize: CGSize(width: 1200, height: 800),
        mixDockWidth: 278,
        bottomChrome: 82,
        energyDomain: 0.2 ... 1.0
    )
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
    let library = try SetaLibrary.decode(from: Data(json.utf8))
    let track = library.tracks[0]
    let pointA = layout.trackPoint(for: track, jitter: true)
    let pointB = layout.trackPoint(for: track, jitter: true)
    check(pointA == pointB, "stable jitter is deterministic")

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

    let domain = MapPlotLayout.computeEnergyDisplayDomain(tracks: library.tracks)
    check(domain.upperBound == 1, "energy display domain top")
}

func smokeRealLibrary() throws {
    let envPath = ProcessInfo.processInfo.environment["SETA_LIBRARY_PATH"]
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let candidates = [
        envPath.map { URL(fileURLWithPath: $0) },
        URL(fileURLWithPath: "\(home)/Music/tracks/tools/seta/library.json")
    ].compactMap { $0 }

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

    if !library.edges.isEmpty, let edge = library.edges.first {
        let byID = Dictionary(uniqueKeysWithValues: library.tracks.map { ($0.id, $0) })
        let links = library.exploreLinks(for: edge.source, tracksByID: byID)
        check(!links.isEmpty, "real explore links resolve")
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

do {
    try decodesCurrentLibraryContract()
    try validationFindsContractIssues()
    camelotParityValues()
    try filterAndDraftHelpers()
    try playbackHelpers()
    draftStoreRoundtrip()
    try setMomentsAndSettingsHelpers()
    try uiGeometryChecks()
    try smokeRealLibrary()
    print("SetaMacChecks: OK")
} catch {
    fputs("FAIL: \(error)\n", stderr)
    exit(1)
}

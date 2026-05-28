import AVFoundation
import AppKit
import SwiftUI
import SetaMacCore
import UniformTypeIdentifiers

enum MixDockTab: String, CaseIterable {
    case neighbors
    case draft
}

@MainActor
final class LibraryStore: ObservableObject {
    // MARK: - Published state

    @Published var library: SetaLibrary?
    @Published var selectedTrackID: String?
    @Published var filter = LibraryFilter()
    @Published var draft = SetaDraft()
    @Published var draftStoreState = DraftStoreState()
    @Published var settings = AppSettings.load()
    @Published var issues: [String] = []
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var highlightNeighbors = false
    @Published var neighborQueueAnchor: String?
    @Published var draftPlayMode = false
    @Published var playQueue: [SetaTrack] = []
    @Published var playIndex = -1
    @Published var playingTrackID: String?
    @Published var showShortcutsHelp = false
    @Published var isRescanning = false
    @Published var mixDockTab: MixDockTab = .neighbors
    @Published var mixDockExpanded = false
    @Published var camelotLegendOpen = false
    @Published var momentsLegendOpen = false
    @Published var queueFocusIndex = -1
    @Published var searchResultsIndex = -1
    @Published var trackOverrides: [String: TrackOverride] = [:]
    @Published var transitionFeedback: [String: TransitionFeedback] = TransitionFeedbackStorage.load()
    @Published var bridgeRoutes: [SmartBridgeRoute] = []
    @Published var draftWeakLinks: [DraftWeakLink] = []
    @Published var showingRekordboxImport = false
    @Published var rekordboxImportCandidates: [PlaylistImportCandidate] = []
    @Published var rekordboxImportMatchedCounts: [Int] = []
    @Published var rekordboxImportMessage: String?
    @Published var isLoadingRekordboxImport = false
    @Published var showingRekordboxFileImporter = false
    @Published var showingLibraryFolders = false
    @Published var excludedTrackPaths: Set<String> = []

    let player = AudioPlayerController()

    // MARK: - Private caches

    private var baseLibrary: SetaLibrary?
    private var playQueueSig = ""
    private var persistWorkItem: DispatchWorkItem?
    private var suppressPlaybackUntil = Date.distantPast
    private var smartNeighborCacheAnchor: String?
    private var smartNeighborCacheSignature = ""
    private var smartNeighborCache: [SmartNeighbor] = []
    private var smartNeighborRevision = 0
    private var libraryRevision = 0
    private var tracksByIDCacheRevision = -1
    private var tracksByIDCache: [String: SetaTrack] = [:]
    private var filteredTracksCacheKey: FilteredTracksCacheKey?
    private var filteredTracksCache: [SetaTrack] = []
    private var filteredTracksIDSignature = ""
    private var energyDomainCacheKey = ""
    private var energyDomainCache: ClosedRange<Double> = EnergyDisplay.fallback

    private struct FilteredTracksCacheKey: Equatable {
        let libraryRevision: Int
        let filter: LibraryFilter
        let draftTrackIDs: [String]
    }

    init() {
        restoreDraft()
        restoreTrackOverrides()
        excludedTrackPaths = ExcludedTracksStorage.load()
        player.onFinished = { [weak self] in
            self?.playRelative(step: 1)
        }
    }

    var needsFolderSetup: Bool {
        !settings.hasConfiguredFolders
    }

    func deferAfterListUpdate(_ work: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            await Task.yield()
            work()
        }
    }

    var selectedTrack: SetaTrack? {
        selectedTrackID.flatMap { tracksByID[$0] }
    }

    var tracksByID: [String: SetaTrack] {
        if tracksByIDCacheRevision == libraryRevision {
            return tracksByIDCache
        }
        let lookup = Dictionary(uniqueKeysWithValues: (library?.tracks ?? []).map { ($0.id, $0) })
        tracksByIDCacheRevision = libraryRevision
        tracksByIDCache = lookup
        return lookup
    }

    var filteredTracks: [SetaTrack] {
        let key = FilteredTracksCacheKey(
            libraryRevision: libraryRevision,
            filter: filter,
            draftTrackIDs: draft.trackIds
        )
        if filteredTracksCacheKey == key {
            return filteredTracksCache
        }
        let tracks = library?.filteredTracks(
            using: filter,
            draftTrackIds: Set(draft.trackIds)
        ) ?? []
        filteredTracksCacheKey = key
        filteredTracksCache = tracks
        filteredTracksIDSignature = tracks.map(\.id).joined(separator: "|")
        return tracks
    }

    var draftTracks: [SetaTrack] {
        draft.resolvedTracks(from: library?.tracks ?? [])
    }

    var draftSummaries: [(id: String, name: String)] {
        draftStoreState.drafts.values
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { ($0.id, $0.name) }
    }

    var neighborAnchorID: String? {
        highlightNeighbors ? (neighborQueueAnchor ?? selectedTrackID) : nil
    }

    var neighborResult: Playback.MixNeighborsResult {
        guard let anchor = neighborAnchorID else {
            return Playback.MixNeighborsResult(ids: [], list: [])
        }
        let neighbors = smartNeighbors(for: anchor)
        var ids = Set(neighbors.map(\.track.id))
        ids.insert(anchor)
        return Playback.MixNeighborsResult(ids: ids, list: neighbors.map(\.track))
    }

    var smartNeighborResult: [SmartNeighbor] {
        guard let anchor = neighborAnchorID else { return [] }
        return smartNeighbors(for: anchor)
    }

    var smartNeighborByID: [String: SmartNeighbor] {
        Dictionary(uniqueKeysWithValues: smartNeighborResult.map { ($0.track.id, $0) })
    }

    var neighborHighlightIDs: Set<String> {
        highlightNeighbors ? neighborResult.ids : []
    }

    var riskyNeighborIDs: Set<String> {
        guard highlightNeighbors else { return [] }
        return Set(smartNeighborResult.filter { $0.score.kind == .risky }.map(\.track.id))
    }

    var mixLinks: [(SetaTrack, SetaTrack)] {
        if let route = bridgeRoutes.first, route.tracks.count >= 2 {
            return Array(zip(route.tracks, route.tracks.dropFirst()))
        }
        guard highlightNeighbors,
              let anchor = neighborAnchorID,
              let source = tracksByID[anchor] else { return [] }
        return neighborResult.list.map { (source, $0) }
    }

    var energyDisplayDomain: ClosedRange<Double> {
        let tracks = filteredTracks
        let cacheKey = "\(libraryRevision)|\(filteredTracksIDSignature)"
        if energyDomainCacheKey == cacheKey {
            return energyDomainCache
        }
        let domain = MapPlotLayout.computeEnergyDisplayDomain(tracks: tracks)
        energyDomainCacheKey = cacheKey
        energyDomainCache = domain
        return domain
    }

    var draftTrackIDSet: Set<String> { Set(draft.trackIds) }
    var draftFinalIDSet: Set<String> { Set(draft.finalIds) }

    var canQueueKeyboardNav: Bool {
        guard mixDockExpanded else { return false }
        if mixDockTab == .draft { return !draft.trackIds.isEmpty }
        return highlightNeighbors && neighborAnchorID != nil
    }

    var queueTrackIDs: [String] {
        if mixDockTab == .draft { return draft.trackIds }
        guard let anchor = neighborAnchorID else { return [] }
        return [anchor] + neighborResult.list.map(\.id)
    }

    var queueFocusTrackID: String? {
        let ids = queueTrackIDs
        guard !ids.isEmpty else { return nil }
        if queueFocusIndex >= 0, queueFocusIndex < ids.count {
            return ids[queueFocusIndex]
        }
        if let preferred = playingTrackID ?? selectedTrackID,
           let index = ids.firstIndex(of: preferred) {
            return ids[index]
        }
        return ids.first
    }

    var searchResultTracks: [SetaTrack] {
        Array(filteredTracks.prefix(12))
    }

    var playbackSelection: Playback.PlaybackSelection {
        Playback.PlaybackSelection(
            highlightNeighbors: highlightNeighbors,
            neighborQueueAnchor: neighborAnchorID,
            draftPlayMode: draftPlayMode,
            draftTrackIds: draft.trackIds,
            draftSortMode: draft.sortMode
        )
    }

    func smartNeighbors(for anchor: String) -> [SmartNeighbor] {
        let tracks = filteredTracks
        let signature = smartNeighborSignature(anchor: anchor)
        if smartNeighborCacheAnchor == anchor, smartNeighborCacheSignature == signature {
            return smartNeighborCache
        }
        let neighbors = SmartMixEngine.neighbors(
            for: anchor,
            in: tracks,
            intent: JourneyIntent(),
            feedback: transitionFeedback
        )
        smartNeighborCacheAnchor = anchor
        smartNeighborCacheSignature = signature
        smartNeighborCache = neighbors
        return neighbors
    }

    private func smartNeighborSignature(anchor: String) -> String {
        let feedbackRevision = transitionFeedback.values.map(\.updatedAt).max() ?? 0
        return "\(smartNeighborRevision)|\(anchor)|\(feedbackRevision)|\(transitionFeedback.count)|\(filteredTracksIDSignature)"
    }

    private func invalidateSmartNeighborCache() {
        smartNeighborRevision += 1
        smartNeighborCacheAnchor = nil
        smartNeighborCacheSignature = ""
        smartNeighborCache = []
    }

    private func invalidateLibraryDerivedCaches() {
        libraryRevision += 1
        tracksByIDCacheRevision = -1
        tracksByIDCache = [:]
        filteredTracksCacheKey = nil
        filteredTracksCache = []
        filteredTracksIDSignature = ""
        energyDomainCacheKey = ""
        energyDomainCache = EnergyDisplay.fallback
        invalidateSmartNeighborCache()
    }
}

// MARK: - Library metadata and loading

extension LibraryStore {
    var availableKeys: [String] {
        let keys = Set((library?.tracks ?? []).compactMap { $0.key?.uppercased() })
        return keys.sorted {
            let numberA = Int($0.dropLast()) ?? 0
            let numberB = Int($1.dropLast()) ?? 0
            if numberA != numberB { return numberA < numberB }
            return $0 < $1
        }
    }

    var availableGenres: [String] {
        let values = (library?.tracks ?? []).flatMap { track in
            [track.genre, track.batch].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        return Array(Set(values)).sorted()
    }

    var scannerRootURL: URL? {
        if let configured = settings.setaScannerRoot {
            return URL(fileURLWithPath: configured)
        }
        let sibling = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("seta")
        if FileManager.default.fileExists(atPath: sibling.appendingPathComponent("scan_library.py").path) {
            return sibling
        }
        let defaultPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Music/tracks/tools/seta")
        return FileManager.default.fileExists(atPath: defaultPath.appendingPathComponent("scan_library.py").path)
            ? defaultPath
            : nil
    }

    func autoLoadLibraryIfPossible() {
        let candidates = AppSettings.defaultLibraryCandidates(scannerRoot: scannerRootURL?.path)
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            load(url: url, remember: false)
            return
        }
    }

    func load(url: URL, remember: Bool = true) {
        do {
            let data = try Data(contentsOf: url)
            let decoded = try SetaLibrary.decode(from: data)
            baseLibrary = decoded
            let libraryWithOverrides = displayedLibrary(from: decoded)
            let decodedIssues = libraryWithOverrides.validationIssues()
            errorMessage = nil
            if remember {
                settings.lastLibraryPath = url.path
                if settings.setaScannerRoot == nil, url.lastPathComponent == "library.json" {
                    settings.setaScannerRoot = url.deletingLastPathComponent().path
                }
                AppSettings.save(settings)
            }
            deferAfterListUpdate {
                self.library = libraryWithOverrides
                self.issues = decodedIssues
                self.invalidateLibraryDerivedCaches()
                self.player.stop()
                self.playingTrackID = nil
                self.suppressPlaybackUntil = Date().addingTimeInterval(1.0)
                if let selectedTrackID = self.selectedTrackID,
                   libraryWithOverrides.tracks.contains(where: { $0.id == selectedTrackID }) == false {
                    self.selectedTrackID = nil
                }
                self.syncPlayQueue()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Track overrides

    func trackOverride(for trackId: String) -> TrackOverride? {
        trackOverrides[trackId]
    }

    private func restoreTrackOverrides() {
        trackOverrides = TrackOverridesStorage.load()
    }

    private func persistTrackOverrides() {
        TrackOverridesStorage.save(trackOverrides)
    }

    private func applyingExclusions(to library: SetaLibrary) -> SetaLibrary {
        guard !excludedTrackPaths.isEmpty else { return library }
        let tracks = library.tracks.filter { !excludedTrackPaths.contains($0.path) }
        let visibleIDs = Set(tracks.map(\.id))
        return SetaLibrary(
            generatedAt: library.generatedAt,
            tracksRoot: library.tracksRoot,
            curateRoot: library.curateRoot,
            tracksRoots: library.tracksRoots,
            curateRoots: library.curateRoots,
            trackCount: tracks.count,
            tracks: tracks,
            edges: library.edges.filter { visibleIDs.contains($0.source) && visibleIDs.contains($0.target) }
        )
    }

    private func applyingTrackOverrides(to library: SetaLibrary) -> SetaLibrary {
        let tracks = library.tracks.map { track in
            track.applyingTrackOverride(trackOverrides[track.id])
        }
        return SetaLibrary(
            generatedAt: library.generatedAt,
            tracksRoot: library.tracksRoot,
            curateRoot: library.curateRoot,
            tracksRoots: library.tracksRoots,
            curateRoots: library.curateRoots,
            trackCount: library.trackCount,
            tracks: tracks,
            edges: library.edges
        )
    }

    private func displayedLibrary(from library: SetaLibrary) -> SetaLibrary {
        applyingTrackOverrides(to: applyingExclusions(to: library))
    }

    private func applyTrackOverridesToCurrentLibrary() {
        guard let baseLibrary else { return }
        library = displayedLibrary(from: baseLibrary)
        invalidateLibraryDerivedCaches()
    }

    private func refreshDisplayedLibrary() {
        guard let baseLibrary else { return }
        library = displayedLibrary(from: baseLibrary)
        issues = library?.validationIssues() ?? []
        invalidateLibraryDerivedCaches()
        syncPlayQueue()
    }

    private func updateTrackOverride(for trackId: String, _ mutate: (inout TrackOverride) -> Void) {
        var override = trackOverrides[trackId] ?? TrackOverride()
        mutate(&override)
        if override.isEmpty {
            trackOverrides.removeValue(forKey: trackId)
        } else {
            trackOverrides[trackId] = TrackOverride.normalized(
                bpm: override.bpm,
                key: override.key,
                energy: override.energy
            )
        }
        persistTrackOverrides()
        applyTrackOverridesToCurrentLibrary()
        syncPlayQueue()
    }

    // MARK: - Library folders and rescanning

    func rescanLibrary() {
        guard let scannerRoot = scannerRootURL else {
            statusMessage = "Seta scanner folder not found."
            return
        }
        guard settings.hasConfiguredFolders else {
            showingLibraryFolders = true
            statusMessage = "Add library folders before scanning."
            return
        }
        isRescanning = true
        let tracksAccess = settings.startAccessingTracksRoots()
        let curateAccess = settings.startAccessingCurateRoots()
        let tracksRoots = tracksAccess.map(\.path)
        let curateRoots = curateAccess.map(\.path)
        let excluded = Array(excludedTrackPaths)
        Task {
            defer {
                tracksAccess.forEach { $0.stopAccessing() }
                curateAccess.forEach { $0.stopAccessing() }
            }
            let result = await Task.detached(priority: .userInitiated) {
                LibraryScanner.scanLibrary(
                    at: scannerRoot,
                    tracksRoots: tracksRoots,
                    curateRoots: curateRoots,
                    excludedPaths: excluded,
                    quick: true
                )
            }.value
            isRescanning = false
            if result.exitCode == 0 {
                let libraryURL = scannerRoot.appendingPathComponent("library.json")
                load(url: libraryURL)
                statusMessage = "Library rescanned."
            } else {
                statusMessage = "Scan failed: \(result.output.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
        }
    }

    func addTracksFolder(url: URL, bookmarkData: Data?) {
        appendFolderEntry(url: url, bookmarkData: bookmarkData, curated: true)
    }

    func addCurateFolder(url: URL, bookmarkData: Data?) {
        appendFolderEntry(url: url, bookmarkData: bookmarkData, curated: false)
    }

    private func appendFolderEntry(url: URL, bookmarkData: Data?, curated: Bool) {
        let path = url.path
        if curated {
            guard !settings.tracksFolders.contains(where: { $0.path == path }) else { return }
            settings.tracksFolders.append(makeFolderEntry(url: url, bookmarkData: bookmarkData))
        } else {
            guard !settings.curateFolders.contains(where: { $0.path == path }) else { return }
            settings.curateFolders.append(makeFolderEntry(url: url, bookmarkData: bookmarkData))
        }
        saveSettings()
    }

    private func makeFolderEntry(url: URL, bookmarkData: Data?) -> LibraryFolderEntry {
        LibraryFolderEntry(
            path: url.path,
            label: url.lastPathComponent,
            bookmarkData: bookmarkData ?? FolderBookmarkAccess.bookmarkData(for: url)
        )
    }

    func removeTracksFolder(id: String) {
        settings.tracksFolders.removeAll { $0.id == id }
        saveSettings()
    }

    func removeCurateFolder(id: String) {
        settings.curateFolders.removeAll { $0.id == id }
        saveSettings()
    }

    func excludeTrackFromLibrary(_ track: SetaTrack) {
        excludedTrackPaths.insert(track.path)
        ExcludedTracksStorage.save(excludedTrackPaths)
        if selectedTrackID == track.id {
            selectedTrackID = nil
        }
        if playingTrackID == track.id {
            stopPlayback()
        }
        draft.remove(trackId: track.id)
        persistDraftNow()
        refreshDisplayedLibrary()
        statusMessage = "Removed from Seta. Rescan to refresh the library file."
    }

    func restoreExcludedTrack(path: String) {
        excludedTrackPaths.remove(path)
        ExcludedTracksStorage.save(excludedTrackPaths)
        refreshDisplayedLibrary()
        statusMessage = "Track restored. Rescan to include it again."
    }

    var excludedTrackPathsSorted: [String] {
        excludedTrackPaths.sorted()
    }

    // MARK: - Filters and dock state

    func toggleSource(_ source: String) {
        if filter.sources.contains(source) && filter.sources.count > 1 {
            filter.sources.remove(source)
        } else {
            filter.sources.insert(source)
        }
        syncPlayQueue()
    }

    func toggleKey(_ key: String) {
        let normalized = key.uppercased()
        if filter.keys.contains(normalized) {
            filter.keys.remove(normalized)
        } else {
            filter.keys.insert(normalized)
        }
        syncPlayQueue()
    }

    func clearKeyFilter() {
        filter.keys.removeAll()
        syncPlayQueue()
    }

    func toggleMoment(_ momentID: String) {
        if filter.moments.contains(momentID) {
            filter.moments.remove(momentID)
        } else {
            filter.moments.insert(momentID)
        }
        syncPlayQueue()
    }

    func clearMomentFilter() {
        filter.moments.removeAll()
        syncPlayQueue()
    }

    func toggleNeighborMode() {
        highlightNeighbors.toggle()
        if highlightNeighbors {
            draftPlayMode = false
            neighborQueueAnchor = selectedTrackID
            bridgeRoutes = []
        }
        syncPlayQueue()
    }

    func toggleDraftPlayMode() {
        draftPlayMode.toggle()
        if draftPlayMode { highlightNeighbors = false }
        syncPlayQueue()
    }

    func openMixDock(tab: MixDockTab) {
        if mixDockExpanded && mixDockTab == tab {
            mixDockExpanded = false
            queueFocusIndex = -1
        } else {
            mixDockTab = tab
            mixDockExpanded = true
            initQueueFocusFromPlayback()
        }
    }

    func copyDraftListToPasteboard() {
        guard let library else { return }
        let text = draft.exportText(from: library.tracks)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        statusMessage = "Draft copied."
    }

    // MARK: - Rekordbox import

    func beginRekordboxImport() {
        showingRekordboxImport = true
        rekordboxImportCandidates = []
        rekordboxImportMatchedCounts = []
        rekordboxImportMessage = nil
        isLoadingRekordboxImport = true

        let root = settings.setaScannerRoot.map { URL(fileURLWithPath: $0) }
        let tracks = library?.tracks ?? []

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                RekordboxLibraryBridge.loadPlaylists(scannerRoot: root)
            }.value
            let counts = RekordboxPlaylistImport.matchedCounts(for: result.playlists, in: tracks)
            rekordboxImportCandidates = result.playlists
            rekordboxImportMatchedCounts = counts
            rekordboxImportMessage = result.message
            isLoadingRekordboxImport = false
        }
    }

    func importRekordboxFile(url: URL) {
        showingRekordboxImport = true
        isLoadingRekordboxImport = true
        rekordboxImportCandidates = []
        rekordboxImportMatchedCounts = []
        rekordboxImportMessage = nil

        let tracks = library?.tracks ?? []
        let accessed = url.startAccessingSecurityScopedResource()

        Task {
            let outcome: (candidates: [PlaylistImportCandidate], message: String?) = await Task.detached(
                priority: .userInitiated
            ) {
                defer {
                    if accessed {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                do {
                    let ext = url.pathExtension.lowercased()
                    if ext == "xml" {
                        return (try RekordboxPlaylistImport.parseRekordboxXML(at: url), nil)
                    }
                    return ([try RekordboxPlaylistImport.parseM3U(at: url)], nil)
                } catch {
                    return ([], "Could not read playlist file.")
                }
            }.value

            isLoadingRekordboxImport = false
            guard !outcome.candidates.isEmpty else {
                showingRekordboxImport = false
                statusMessage = outcome.message ?? "No playlists found in that file."
                return
            }
            rekordboxImportCandidates = outcome.candidates
            rekordboxImportMatchedCounts = RekordboxPlaylistImport.matchedCounts(
                for: outcome.candidates,
                in: tracks
            )
            rekordboxImportMessage = outcome.message
        }
    }

    func importRekordboxCandidate(_ candidate: PlaylistImportCandidate) {
        guard let library else { return }
        let match = RekordboxPlaylistImport.matchPaths(candidate.paths, in: library.tracks)
        guard !match.matchedTrackIds.isEmpty else {
            statusMessage = "No tracks from \"\(candidate.name)\" were found in your Seta library."
            return
        }

        persistDraftNow()
        var imported = DraftStore.createDraft(name: candidate.name)
        imported.trackIds = match.matchedTrackIds
        imported.sortMode = .manual
        draftStoreState.drafts[imported.id] = imported
        draftStoreState.activeId = imported.id
        draft = imported
        DraftStore.save(draftStoreState)
        mixDockTab = .draft
        mixDockExpanded = true
        draftPlayMode = false
        syncPlayQueue()
        showingRekordboxImport = false

        if match.skippedCount > 0 {
            statusMessage = "Imported \(match.matchedCount) of \(match.totalCount) tracks into \"\(candidate.name)\"."
        } else {
            statusMessage = "Imported \(match.matchedCount) tracks into \"\(candidate.name)\"."
        }
    }

    func rekordboxMatchedCount(at index: Int) -> Int {
        guard rekordboxImportMatchedCounts.indices.contains(index) else { return 0 }
        return rekordboxImportMatchedCounts[index]
    }

    // MARK: - Neighbor queue

    func setNeighborAnchor(_ trackId: String) {
        reanchorNeighborQueue(trackId: trackId)
    }

    func reanchorFromShortcut() {
        guard mixDockTab != .draft else { return }
        if canQueueKeyboardNav, let trackId = queueFocusTrackID {
            reanchorNeighborQueue(trackId: trackId)
            return
        }
        if let selectedTrackID {
            reanchorNeighborQueue(trackId: selectedTrackID)
        }
    }

    func reanchorNeighborQueue(trackId: String) {
        guard library?.tracks.contains(where: { $0.id == trackId }) == true else { return }
        neighborQueueAnchor = trackId
        selectedTrackID = trackId
        highlightNeighbors = true
        draftPlayMode = false
        bridgeRoutes = []
        syncPlayQueue()
        playAudio(id: trackId, keepSelection: trackId)
        queueFocusIndex = 0
    }

    // MARK: - Drafts

    func selectDraft(id: String) {
        persistDraftNow()
        guard let next = draftStoreState.drafts[id] else { return }
        draftStoreState.activeId = id
        draft = next
        DraftStore.save(draftStoreState)
        deferAfterListUpdate { self.syncPlayQueue() }
    }

    func createDraft() {
        persistDraftNow()
        let created = DraftStore.createDraft()
        draftStoreState.drafts[created.id] = created
        draftStoreState.activeId = created.id
        draft = created
        DraftStore.save(draftStoreState)
    }

    func deleteActiveDraft() {
        guard let activeId = draftStoreState.activeId else { return }
        draftStoreState.drafts.removeValue(forKey: activeId)
        if let next = draftStoreState.drafts.values.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
            draftStoreState.activeId = next.id
            draft = next
        } else {
            let created = DraftStore.createDraft()
            draftStoreState.drafts[created.id] = created
            draftStoreState.activeId = created.id
            draft = created
        }
        DraftStore.save(draftStoreState)
        syncPlayQueue()
    }

    func addTrackToDraft(_ trackId: String) {
        draft.add(trackId: trackId)
        persistDraftSoon()
    }

    func addTrackToDraftAfterAnchor(_ trackId: String) {
        guard !trackId.isEmpty else { return }
        if draft.trackIds.contains(trackId) {
            statusMessage = "Already in draft."
            return
        }
        if let anchor = neighborAnchorID ?? selectedTrackID,
           let index = draft.trackIds.firstIndex(of: anchor) {
            var ids = draft.trackIds
            ids.insert(trackId, at: index + 1)
            draft.reorderTrackIds(ids)
        } else {
            draft.add(trackId: trackId)
        }
        persistDraftSoon()
        statusMessage = "Added after anchor."
    }

    func addSelectedToDraft() {
        guard let selectedTrackID else { return }
        addTrackToDraft(selectedTrackID)
    }

    func removeFromDraft(_ trackId: String) {
        draft.remove(trackId: trackId)
        persistDraftSoon()
        deferAfterListUpdate { self.syncPlayQueue() }
    }

    func toggleFinal(_ trackId: String) {
        draft.toggleFinal(trackId: trackId)
        persistDraftSoon()
    }

    func setDraftNote(_ note: String, for trackId: String) {
        draft.setNote(note, for: trackId)
        persistDraftSoon()
    }

    // MARK: - Smart journey actions

    func markTransition(_ trackId: String, rating: Int) {
        guard let anchor = neighborAnchorID ?? selectedTrackID else { return }
        let item = TransitionFeedback(
            fromTrackID: anchor,
            toTrackID: trackId,
            rating: rating
        )
        transitionFeedback[item.id] = item
        TransitionFeedbackStorage.save(transitionFeedback)
        invalidateSmartNeighborCache()
        syncPlayQueue()
        statusMessage = rating > 0 ? "Transition marked as working." : "Transition marked as not working."
    }

    func explainCandidate(_ trackId: String) {
        guard let candidate = smartNeighborByID[trackId] else { return }
        let reasons = candidate.score.reasons.joined(separator: ", ")
        let warnings = candidate.score.warnings.isEmpty
            ? ""
            : " · \(candidate.score.warnings.joined(separator: ", "))"
        statusMessage = "\(candidate.score.kind.rawValue): \(reasons)\(warnings)"
    }

    func findBridge(to trackId: String? = nil) {
        guard let anchor = neighborAnchorID ?? selectedTrackID else { return }
        bridgeRoutes = SmartMixEngine.bridgeRoutes(
            from: anchor,
            to: trackId,
            in: filteredTracks,
            intent: JourneyIntent(mode: .bridge, targetTrackID: trackId),
            feedback: transitionFeedback
        )
        if bridgeRoutes.isEmpty {
            statusMessage = "No bridge route found in current filters."
        } else {
            statusMessage = "Found \(bridgeRoutes.count) bridge route\(bridgeRoutes.count == 1 ? "" : "s")."
        }
    }

    func analyzeDraft() {
        draftWeakLinks = SmartMixEngine.draftWeakLinks(
            draft: draft,
            tracks: library?.tracks ?? [],
            feedback: transitionFeedback
        )
        if draftWeakLinks.isEmpty {
            statusMessage = "Draft transitions look solid."
        } else {
            statusMessage = "Found \(draftWeakLinks.count) draft link\(draftWeakLinks.count == 1 ? "" : "s") to review."
        }
    }

    func applyDraftSuggestion(_ suggestion: DraftSuggestion, after fromTrackID: String) {
        guard !suggestion.trackIDs.isEmpty,
              let index = draft.trackIds.firstIndex(of: fromTrackID) else { return }
        var ids = draft.trackIds
        let inserts = suggestion.trackIDs.filter { !ids.contains($0) }
        guard !inserts.isEmpty else {
            statusMessage = "Suggested bridge is already in the draft."
            return
        }
        ids.insert(contentsOf: inserts, at: index + 1)
        draft.reorderTrackIds(ids)
        persistDraftSoon()
        analyzeDraft()
        statusMessage = "Applied bridge suggestion."
    }

    func moveDraftTrack(from source: IndexSet, to destination: Int) {
        var ids = draftTracks.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        draft.reorderTrackIds(ids)
        deferAfterListUpdate {
            self.persistDraftSoon()
            self.syncPlayQueue()
        }
    }

    func moveDraftTrack(id trackId: String, toIndex targetIndex: Int) {
        var ids = draftTracks.map(\.id)
        guard let sourceIndex = ids.firstIndex(of: trackId), sourceIndex != targetIndex else { return }
        ids.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: targetIndex)
        draft.reorderTrackIds(ids)
        deferAfterListUpdate {
            self.persistDraftSoon()
            self.syncPlayQueue()
        }
    }

    func moveDraftTrackUp(_ trackId: String) {
        let ids = draftTracks.map(\.id)
        guard let index = ids.firstIndex(of: trackId), index > 0 else { return }
        var reordered = ids
        reordered.swapAt(index, index - 1)
        draft.reorderTrackIds(reordered)
        deferAfterListUpdate {
            self.persistDraftSoon()
            self.syncPlayQueue()
        }
    }

    func moveDraftTrackDown(_ trackId: String) {
        let ids = draftTracks.map(\.id)
        guard let index = ids.firstIndex(of: trackId), index < ids.count - 1 else { return }
        var reordered = ids
        reordered.swapAt(index, index + 1)
        draft.reorderTrackIds(reordered)
        deferAfterListUpdate {
            self.persistDraftSoon()
            self.syncPlayQueue()
        }
    }

    func sortDraftByEnergy() {
        draft.sortMode = .energy
        persistDraftSoon()
        syncPlayQueue()
    }

    func sortDraftByBPM() {
        draft.sortMode = .bpm
        persistDraftSoon()
        syncPlayQueue()
    }

    func setManualBPM(_ value: Double, for trackId: String) {
        updateTrackOverride(for: trackId) { $0.bpm = value }
    }

    func clearManualBPM(for trackId: String) {
        updateTrackOverride(for: trackId) { $0.bpm = nil }
    }

    func setManualKey(_ value: String, for trackId: String) {
        updateTrackOverride(for: trackId) { $0.key = value }
    }

    func clearManualKey(for trackId: String) {
        updateTrackOverride(for: trackId) { $0.key = nil }
    }

    func setManualEnergy(_ value: Double, for trackId: String) {
        updateTrackOverride(for: trackId) { $0.energy = value }
    }

    func clearManualEnergy(for trackId: String) {
        updateTrackOverride(for: trackId) { $0.energy = nil }
    }

    // MARK: - Playback

    func playSelected() {
        guard let selectedTrackID else { return }
        playTrack(id: selectedTrackID)
    }

    func playDraftFromStart() {
        draftPlayMode = true
        highlightNeighbors = false
        syncPlayQueue()
        guard let first = playQueue.first else { return }
        playTrack(id: first.id)
    }

    func playDraftTrack(_ trackId: String) {
        draftPlayMode = true
        highlightNeighbors = false
        syncPlayQueue()
        playTrackViaView(id: trackId)
    }

    func playRelative(step: Int) {
        syncPlayQueue()
        guard !playQueue.isEmpty else { return }
        let nextIndex = Playback.nextPlayIndex(
            queue: playQueue,
            currentId: playingTrackID,
            currentIndex: playIndex,
            step: step
        )
        playIndex = nextIndex
        let nextId = playQueue[nextIndex].id
        if highlightNeighbors, let anchorId = neighborAnchorID {
            playAudio(id: nextId, keepSelection: anchorId)
        } else {
            playTrack(id: nextId)
        }
    }

    func stopPlayback() {
        player.stop()
        playingTrackID = nil
    }

    func togglePlayPause() {
        if player.isPlaying || (player.errorMessage == nil && playingTrackID != nil) {
            player.togglePause()
        } else {
            playSelected()
        }
    }

    func seekRelative(_ delta: TimeInterval) {
        player.seekRelative(delta)
    }

    func seekToProgress(_ progress: Double) {
        player.seek(to: player.duration * progress)
    }

    func syncPlayQueue() {
        if highlightNeighbors, let anchorId = neighborAnchorID {
            let filteredIDs = Set(filteredTracks.map(\.id))
            if bridgeRoutes.contains(where: { route in
                route.tracks.contains { !filteredIDs.contains($0.id) }
            }) {
                bridgeRoutes = []
            }
            let queue = [tracksByID[anchorId]].compactMap { $0 } + smartNeighbors(for: anchorId).map(\.track)
            let signature = Playback.queueSignature(queue)
            if signature != playQueueSig || playQueue.isEmpty {
                playQueue = queue
                playQueueSig = signature
                playIndex = Playback.resolvePlayIndex(queue: queue, trackId: playingTrackID ?? selectedTrackID)
            }
            if let playingTrackID, !playQueue.contains(where: { $0.id == playingTrackID }) {
                self.playingTrackID = nil
                player.stop()
            }
            return
        }

        var state = Playback.PlayQueueState(
            playingId: playingTrackID,
            selectedId: selectedTrackID,
            playQueue: playQueue,
            playQueueSig: playQueueSig,
            playIndex: playIndex
        )
        let result = Playback.syncPlayQueueState(
            &state,
            filtered: filteredTracks,
            selection: playbackSelection
        )
        playQueue = state.playQueue
        playQueueSig = state.playQueueSig
        playIndex = state.playIndex
        if result.changed, let playingTrackID,
           !playQueue.contains(where: { $0.id == playingTrackID }) {
            self.playingTrackID = nil
            player.stop()
        }
    }

    // MARK: - Draft export

    func exportDraftM3U() {
        guard let library else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText, .data]
        panel.nameFieldStringValue = sanitizedDraftFilename(extension: "m3u")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let text = self.draft.exportM3U(from: library.tracks)
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func exportDraftText() {
        guard let library else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = sanitizedDraftFilename(extension: "txt")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let text = self.draft.exportText(from: library.tracks)
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Keyboard focus and search

    func playTrackViaView(id: String, reanchor: Bool = false) {
        guard library?.tracks.contains(where: { $0.id == id }) == true else { return }
        if highlightNeighbors {
            if reanchor {
                reanchorNeighborQueue(trackId: id)
            } else {
                playInNeighborMode(id: id)
            }
        } else {
            playTrack(id: id)
        }
        syncQueueFocus(to: id)
    }

    private func playInNeighborMode(id: String) {
        if let anchorId = neighborAnchorID {
            if neighborResult.ids.contains(id) {
                syncPlayQueue()
                playAudio(id: id, keepSelection: anchorId)
                return
            }
        }
        reanchorNeighborQueue(trackId: id)
    }

    func syncQueueFocus(to trackID: String?) {
        guard canQueueKeyboardNav, let trackID else {
            queueFocusIndex = -1
            return
        }
        queueFocusIndex = queueTrackIDs.firstIndex(of: trackID) ?? -1
    }

    func initQueueFocusFromPlayback() {
        guard canQueueKeyboardNav else {
            queueFocusIndex = -1
            return
        }
        let preferred = playingTrackID ?? selectedTrackID
        queueFocusIndex = preferred.flatMap { queueTrackIDs.firstIndex(of: $0) } ?? -1
    }

    func moveQueueFocus(step: Int) {
        let ids = queueTrackIDs
        guard !ids.isEmpty else { return }
        if queueFocusIndex < 0 {
            initQueueFocusFromPlayback()
            if queueFocusIndex < 0 { queueFocusIndex = 0 }
        } else {
            queueFocusIndex = (queueFocusIndex + step + ids.count) % ids.count
        }
    }

    func activateQueueFocus() {
        guard let id = queueFocusTrackID else { return }
        playTrackViaView(id: id)
    }

    func resetSearchResultsIndex() {
        searchResultsIndex = -1
    }

    func moveSearchResultsHighlight(delta: Int) {
        let tracks = searchResultTracks
        guard !tracks.isEmpty else { return }
        if searchResultsIndex < 0 {
            searchResultsIndex = delta > 0 ? 0 : tracks.count - 1
        } else {
            searchResultsIndex = (searchResultsIndex + delta + tracks.count) % tracks.count
        }
    }

    func activateSearchResult() {
        let tracks = searchResultTracks
        guard !tracks.isEmpty else { return }
        let index: Int
        if searchResultsIndex >= 0 {
            index = searchResultsIndex
        } else if tracks.count == 1 {
            index = 0
        } else {
            return
        }
        guard index < tracks.count else { return }
        let track = tracks[index]
        filter.query = ""
        searchResultsIndex = -1
        playTrackViaView(id: track.id)
    }

    // MARK: - Persistence helpers

    func persistDraftSoonViaView() {
        persistDraftSoon()
    }

    func saveSettings() {
        AppSettings.save(settings)
    }

    private func playTrack(id: String) {
        playAudio(id: id, keepSelection: id)
    }

    private func playAudio(id: String, keepSelection selectedId: String) {
        guard let track = library?.tracks.first(where: { $0.id == id }) else { return }
        selectedTrackID = selectedId
        guard Date() >= suppressPlaybackUntil else { return }
        if player.play(track: track) {
            playingTrackID = id
            playIndex = Playback.resolvePlayIndex(queue: playQueue, trackId: id)
        } else {
            playingTrackID = nil
        }
    }

    private func restoreDraft() {
        draftStoreState = DraftStore.load()
        if let active = DraftStore.activeDraft(from: draftStoreState) {
            draft = active
        } else {
            draft = DraftStore.createDraft()
            draftStoreState.drafts[draft.id] = draft
            draftStoreState.activeId = draft.id
            DraftStore.save(draftStoreState)
        }
    }

    private func persistDraftSoon() {
        persistWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.persistDraftNow()
            }
        }
        persistWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func persistDraftNow() {
        DraftStore.upsertActiveDraft(&draftStoreState, draft: draft)
        DraftStore.save(draftStoreState)
    }

    private func sanitizedDraftFilename(extension ext: String) -> String {
        let base = draft.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
        let safe = base.isEmpty ? "set-draft" : base
        return "\(safe).\(ext)"
    }
}

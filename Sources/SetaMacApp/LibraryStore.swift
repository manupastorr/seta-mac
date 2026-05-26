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
    @Published var energyOverrides: [String: Double] = [:]

    let player = AudioPlayerController()

    private var playQueueSig = ""
    private var persistWorkItem: DispatchWorkItem?
    private var suppressPlaybackUntil = Date.distantPast
    private let maxMapGraphEdges = 1800
    private let energyOverridesKey = "seta-energy-overrides-v1"

    init() {
        restoreDraft()
        restoreEnergyOverrides()
        player.onFinished = { [weak self] in
            self?.playRelative(step: 1)
        }
    }

    func deferAfterListUpdate(_ work: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            await Task.yield()
            work()
        }
    }

    var selectedTrack: SetaTrack? {
        library?.tracks.first { $0.id == selectedTrackID }
    }

    var tracksByID: [String: SetaTrack] {
        Dictionary(uniqueKeysWithValues: (library?.tracks ?? []).map { ($0.id, $0) })
    }

    var filteredTracks: [SetaTrack] {
        library?.filteredTracks(
            using: filter,
            draftTrackIds: Set(draft.trackIds)
        ) ?? []
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
        return Playback.mixNeighbors(trackId: anchor, tracks: filteredTracks)
    }

    var neighborHighlightIDs: Set<String> {
        highlightNeighbors ? neighborResult.ids : []
    }

    var exploreLinks: [(SetaTrack, Double)] {
        guard settings.showExploreLinks,
              let library,
              let selectedTrackID else { return [] }
        return library.exploreLinks(for: selectedTrackID, tracksByID: tracksByID)
    }

    var mapGraphEdges: [(SetaTrack, SetaTrack, Double)] {
        guard settings.showExploreLinks, let library else { return [] }
        let ids = Set(filteredTracks.map(\.id))
        let byID = tracksByID
        return library.visibleEdges(trackIDs: ids)
            .sorted { $0.score > $1.score }
            .prefix(maxMapGraphEdges)
            .compactMap { edge in
                guard let source = byID[edge.source], let target = byID[edge.target] else { return nil }
                return (source, target, edge.score)
            }
    }

    var mixLinks: [(SetaTrack, SetaTrack)] {
        guard highlightNeighbors,
              let anchor = neighborAnchorID,
              let source = tracksByID[anchor] else { return [] }
        return neighborResult.list.map { (source, $0) }
    }

    var energyDisplayDomain: ClosedRange<Double> {
        MapPlotLayout.computeEnergyDisplayDomain(tracks: filteredTracks)
    }

    var draftTrackIDSet: Set<String> { Set(draft.trackIds) }
    var draftFinalIDSet: Set<String> { Set(draft.finalIds) }

    var libraryHasMixEdges: Bool {
        library?.hasMixEdges ?? false
    }

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
            let decoded = applyingEnergyOverrides(to: try SetaLibrary.decode(from: data))
            let decodedIssues = decoded.validationIssues()
            errorMessage = nil
            if remember {
                settings.lastLibraryPath = url.path
                if settings.setaScannerRoot == nil, url.lastPathComponent == "library.json" {
                    settings.setaScannerRoot = url.deletingLastPathComponent().path
                }
                AppSettings.save(settings)
            }
            deferAfterListUpdate {
                self.library = decoded
                self.issues = decodedIssues
                self.player.stop()
                self.playingTrackID = nil
                self.suppressPlaybackUntil = Date().addingTimeInterval(1.0)
                if let selectedTrackID = self.selectedTrackID,
                   decoded.tracks.contains(where: { $0.id == selectedTrackID }) == false {
                    self.selectedTrackID = nil
                }
                self.syncPlayQueue()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restoreEnergyOverrides() {
        guard let raw = UserDefaults.standard.dictionary(forKey: energyOverridesKey) as? [String: Double] else {
            energyOverrides = [:]
            return
        }
        energyOverrides = raw.filter { $0.value.isFinite }.mapValues { min(1, max(0, $0)) }
    }

    private func persistEnergyOverrides() {
        UserDefaults.standard.set(energyOverrides, forKey: energyOverridesKey)
    }

    private func applyingEnergyOverrides(to library: SetaLibrary) -> SetaLibrary {
        let tracks = library.tracks.map { track in
            track.applyingManualEnergy(energyOverrides[track.id])
        }
        return SetaLibrary(
            generatedAt: library.generatedAt,
            tracksRoot: library.tracksRoot,
            curateRoot: library.curateRoot,
            trackCount: library.trackCount,
            tracks: tracks,
            edges: library.edges
        )
    }

    private func applyEnergyOverridesToCurrentLibrary() {
        guard let library else { return }
        self.library = applyingEnergyOverrides(to: library)
    }

    func rescanLibrary(fullEdges: Bool = false) {
        guard let scannerRoot = scannerRootURL else {
            statusMessage = "Seta scanner folder not found."
            return
        }
        isRescanning = true
        Task {
            let result = LibraryScanner.scanLibrary(at: scannerRoot, quick: !fullEdges)
            await MainActor.run {
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
    }

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
        syncPlayQueue()
        playAudio(id: trackId, keepSelection: trackId)
        queueFocusIndex = 0
    }

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

    func setManualEnergy(_ value: Double, for trackId: String) {
        energyOverrides[trackId] = min(1, max(0, value))
        persistEnergyOverrides()
        applyEnergyOverridesToCurrentLibrary()
        syncPlayQueue()
    }

    func clearManualEnergy(for trackId: String) {
        energyOverrides.removeValue(forKey: trackId)
        persistEnergyOverrides()
        applyEnergyOverridesToCurrentLibrary()
        syncPlayQueue()
    }

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
            let neighbors = Playback.mixNeighbors(trackId: anchorId, tracks: filteredTracks)
            if neighbors.ids.contains(id) {
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
        playingTrackID = id
        playIndex = Playback.resolvePlayIndex(queue: playQueue, trackId: id)
        player.play(track: track)
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

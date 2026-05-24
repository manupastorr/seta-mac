import Foundation

public enum Playback {
    public static let mixMinScore = 0.55

    public static func mixScore(_ a: SetaTrack, _ b: SetaTrack) -> Double {
        guard
            let keyA = a.key, let keyB = b.key,
            let bpmA = a.bpm, let bpmB = b.bpm,
            !keyA.isEmpty, !keyB.isEmpty
        else {
            return 0
        }
        return Camelot.mixScore(keyA: keyA, keyB: keyB, bpmA: bpmA, bpmB: bpmB)
    }

    public struct MixNeighborsResult: Equatable {
        public var ids: Set<String>
        public var list: [SetaTrack]

        public init(ids: Set<String>, list: [SetaTrack]) {
            self.ids = ids
            self.list = list
        }
    }

    public static func mixNeighbors(
        trackId: String,
        tracks: [SetaTrack],
        minScore: Double = mixMinScore
    ) -> MixNeighborsResult {
        guard let selected = tracks.first(where: { $0.id == trackId }) else {
            return MixNeighborsResult(ids: [trackId], list: [])
        }

        let list = tracks
            .filter { $0.id != trackId && mixScore(selected, $0) >= minScore }
            .sorted { mixScore(selected, $0) > mixScore(selected, $1) }
        var ids = Set(list.map(\.id))
        ids.insert(trackId)
        return MixNeighborsResult(ids: ids, list: list)
    }

    public struct PlaybackSelection: Equatable {
        public var highlightNeighbors: Bool
        public var neighborQueueAnchor: String?
        public var draftPlayMode: Bool
        public var draftTrackIds: [String]
        public var draftSortMode: DraftSortMode

        public init(
            highlightNeighbors: Bool = false,
            neighborQueueAnchor: String? = nil,
            draftPlayMode: Bool = false,
            draftTrackIds: [String] = [],
            draftSortMode: DraftSortMode = .energy
        ) {
            self.highlightNeighbors = highlightNeighbors
            self.neighborQueueAnchor = neighborQueueAnchor
            self.draftPlayMode = draftPlayMode
            self.draftTrackIds = draftTrackIds
            self.draftSortMode = draftSortMode
        }
    }

    public static func buildDraftQueue(
        filtered: [SetaTrack],
        draftTrackIds: [String],
        sortMode: DraftSortMode = .energy
    ) -> [SetaTrack] {
        guard !draftTrackIds.isEmpty else { return [] }
        let byId = Dictionary(uniqueKeysWithValues: filtered.map { ($0.id, $0) })
        let tracks = draftTrackIds.compactMap { byId[$0] }
        let draft = SetaDraft(trackIds: tracks.map(\.id), sortMode: sortMode)
        return draft.resolvedTracks(from: filtered)
    }

    public static func buildNavigableTracks(
        filtered: [SetaTrack],
        selection: PlaybackSelection
    ) -> [SetaTrack] {
        if selection.draftPlayMode, !selection.draftTrackIds.isEmpty {
            return buildDraftQueue(
                filtered: filtered,
                draftTrackIds: selection.draftTrackIds,
                sortMode: selection.draftSortMode
            )
        }

        if selection.highlightNeighbors, let anchorId = selection.neighborQueueAnchor {
            let neighbors = mixNeighbors(trackId: anchorId, tracks: filtered)
            guard let anchor = filtered.first(where: { $0.id == anchorId }) else {
                return filtered
            }
            return [anchor] + neighbors.list
        }

        return filtered
    }

    public static func queueSignature(_ queue: [SetaTrack]) -> String {
        queue.map(\.id).joined(separator: "\0")
    }

    public static func resolvePlayIndex(queue: [SetaTrack], trackId: String?) -> Int {
        guard !queue.isEmpty else { return -1 }
        guard let trackId else { return 0 }
        let index = queue.firstIndex { $0.id == trackId }
        return index ?? 0
    }

    public static func advancePlayIndex(queue: [SetaTrack], currentIndex: Int, step: Int) -> Int {
        guard !queue.isEmpty else { return -1 }
        let length = queue.count
        if length == 1 { return 0 }

        let base = (0..<length).contains(currentIndex) ? currentIndex : 0
        var index = (base + step) % length
        if index < 0 { index += length }
        if index == base {
            index = step >= 0 ? (base + 1) % length : (base - 1 + length) % length
        }
        return index
    }

    public static func nextPlayIndex(
        queue: [SetaTrack],
        currentId: String?,
        currentIndex: Int,
        step: Int
    ) -> Int {
        let base = currentIndex >= 0 ? currentIndex : resolvePlayIndex(queue: queue, trackId: currentId)
        return advancePlayIndex(queue: queue, currentIndex: base, step: step)
    }

    public struct PlayQueueState: Equatable {
        public var playingId: String?
        public var selectedId: String?
        public var playQueue: [SetaTrack]
        public var playQueueSig: String
        public var playIndex: Int

        public init(
            playingId: String? = nil,
            selectedId: String? = nil,
            playQueue: [SetaTrack] = [],
            playQueueSig: String = "",
            playIndex: Int = -1
        ) {
            self.playingId = playingId
            self.selectedId = selectedId
            self.playQueue = playQueue
            self.playQueueSig = playQueueSig
            self.playIndex = playIndex
        }
    }

    public struct SyncResult: Equatable {
        public var changed: Bool
        public var queue: [SetaTrack]

        public init(changed: Bool, queue: [SetaTrack]) {
            self.changed = changed
            self.queue = queue
        }
    }

    public static func syncPlayQueueState(
        _ state: inout PlayQueueState,
        filtered: [SetaTrack],
        selection: PlaybackSelection
    ) -> SyncResult {
        let queue = buildNavigableTracks(filtered: filtered, selection: selection)
        let signature = queueSignature(queue)
        if signature == state.playQueueSig, !state.playQueue.isEmpty {
            return SyncResult(changed: false, queue: state.playQueue)
        }

        let preferred = state.playingId ?? state.selectedId
        state.playQueue = queue
        state.playQueueSig = signature
        state.playIndex = resolvePlayIndex(queue: queue, trackId: preferred)
        return SyncResult(changed: true, queue: queue)
    }
}

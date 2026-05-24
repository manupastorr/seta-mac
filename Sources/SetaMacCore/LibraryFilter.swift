import Foundation

public struct LibraryFilter: Equatable {
    public var query: String
    public var sources: Set<String>
    public var bpmMin: Double
    public var bpmMax: Double
    public var keys: Set<String>
    public var moments: Set<String>
    public var genre: String
    public var draftOnly: Bool

    public init(
        query: String = "",
        sources: Set<String> = ["tracks", "to_curate"],
        bpmMin: Double = 70,
        bpmMax: Double = 180,
        keys: Set<String> = [],
        moments: Set<String> = [],
        genre: String = "all",
        draftOnly: Bool = false
    ) {
        self.query = query
        self.sources = sources
        self.bpmMin = bpmMin
        self.bpmMax = bpmMax
        self.keys = keys
        self.moments = moments
        self.genre = genre
        self.draftOnly = draftOnly
    }

    public func matches(_ track: SetaTrack, draftTrackIds: Set<String> = []) -> Bool {
        if draftOnly, !draftTrackIds.contains(track.id) { return false }
        if !sources.contains(track.source) { return false }
        if !SetMoments.matchesAnyActiveMoments(track, activeMomentIDs: moments) { return false }
        if genre != "all" {
            let matchesGenre = track.genre == genre || track.batch == genre
            if !matchesGenre { return false }
        }
        if let bpm = track.bpm, (bpm < bpmMin || bpm > bpmMax) { return false }
        if !keys.isEmpty {
            guard let key = track.key?.uppercased(), keys.contains(key) else { return false }
        }

        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !needle.isEmpty {
            let haystack = [
                track.artist,
                track.title,
                track.genre,
                track.batch
            ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
            if !haystack.contains(needle) { return false }
        }

        return true
    }
}

public extension SetaLibrary {
    func filteredTracks(using filter: LibraryFilter, draftTrackIds: Set<String> = []) -> [SetaTrack] {
        tracks.filter { filter.matches($0, draftTrackIds: draftTrackIds) }
    }
}


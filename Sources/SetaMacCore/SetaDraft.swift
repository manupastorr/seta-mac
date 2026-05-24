import Foundation

public enum DraftSortMode: String, Codable, CaseIterable {
    case manual
    case energy
    case bpm
}

public struct SetaDraft: Codable, Equatable {
    public var id: String
    public var name: String
    public var trackIds: [String]
    public var finalIds: [String]
    public var notes: [String: String]
    public var sortMode: DraftSortMode
    public var updatedAt: TimeInterval

    public init(
        id: String = "draft-default",
        name: String = "Set draft",
        trackIds: [String] = [],
        finalIds: [String] = [],
        notes: [String: String] = [:],
        sortMode: DraftSortMode = .energy,
        updatedAt: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.name = name
        self.trackIds = trackIds
        self.finalIds = finalIds
        self.notes = notes
        self.sortMode = sortMode
        self.updatedAt = updatedAt
    }

    public mutating func add(trackId: String) {
        guard !trackId.isEmpty, !trackIds.contains(trackId) else { return }
        trackIds.append(trackId)
        touch()
    }

    public mutating func remove(trackId: String) {
        trackIds.removeAll { $0 == trackId }
        finalIds.removeAll { $0 == trackId }
        notes.removeValue(forKey: trackId)
        touch()
    }

    public mutating func toggleFinal(trackId: String) {
        guard trackIds.contains(trackId) else { return }
        if finalIds.contains(trackId) {
            finalIds.removeAll { $0 == trackId }
        } else {
            finalIds.append(trackId)
        }
        touch()
    }

    public mutating func setNote(_ note: String, for trackId: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            notes.removeValue(forKey: trackId)
        } else {
            notes[trackId] = trimmed
        }
        touch()
    }

    public mutating func reorderTrackIds(_ ids: [String]) {
        trackIds = ids
        sortMode = .manual
        touch()
    }

    public mutating func move(trackId: String, to newIndex: Int) {
        var ids = trackIds.filter { $0 != trackId }
        let clamped = max(0, min(newIndex, ids.count))
        ids.insert(trackId, at: clamped)
        trackIds = ids
        sortMode = .manual
        touch()
    }

    public func resolvedTracks(from tracks: [SetaTrack]) -> [SetaTrack] {
        let byId = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        let ordered = trackIds.compactMap { byId[$0] }
        switch sortMode {
        case .manual:
            return ordered
        case .energy:
            return ordered.sorted {
                if ($0.energy ?? 0) != ($1.energy ?? 0) {
                    return ($0.energy ?? 0) < ($1.energy ?? 0)
                }
                return ($0.bpm ?? 0) < ($1.bpm ?? 0)
            }
        case .bpm:
            return ordered.sorted {
                if ($0.bpm ?? .infinity) != ($1.bpm ?? .infinity) {
                    return ($0.bpm ?? .infinity) < ($1.bpm ?? .infinity)
                }
                return ($0.energy ?? 0) < ($1.energy ?? 0)
            }
        }
    }

    public func exportM3U(from tracks: [SetaTrack]) -> String {
        var lines = ["#EXTM3U"]
        for track in resolvedTracks(from: tracks) {
            lines.append("#EXTINF:-1,\(track.displayArtist) - \(track.displayTitle)")
            lines.append(track.path)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public func exportText(from tracks: [SetaTrack]) -> String {
        resolvedTracks(from: tracks).enumerated().map { index, track in
            let meta = [
                track.bpm.map { "\(Int(round($0))) BPM" },
                track.key,
                track.energy.map { String(format: "E %.2f", $0) }
            ].compactMap { $0 }.joined(separator: " · ")
            let star = finalIds.contains(track.id) ? "* " : ""
            let note = notes[track.id].map { " - \($0)" } ?? ""
            return "\(index + 1). \(star)\(track.displayArtist) - \(track.displayTitle)\(meta.isEmpty ? "" : " (\(meta))")\(note)"
        }.joined(separator: "\n")
    }

    private mutating func touch() {
        updatedAt = Date().timeIntervalSince1970
    }
}


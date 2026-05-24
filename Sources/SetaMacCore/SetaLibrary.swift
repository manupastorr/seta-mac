import Foundation

public struct SetaLibrary: Decodable, Equatable {
    public let generatedAt: String?
    public let tracksRoot: String?
    public let curateRoot: String?
    public let trackCount: Int
    public let tracks: [SetaTrack]
    public let edges: [SetaEdge]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case tracksRoot = "tracks_root"
        case curateRoot = "curate_root"
        case trackCount = "track_count"
        case tracks
        case edges
    }

    public static func decode(from data: Data) throws -> SetaLibrary {
        try JSONDecoder().decode(SetaLibrary.self, from: data)
    }

    public func validationIssues() -> [String] {
        var issues: [String] = []
        if trackCount != tracks.count {
            issues.append("track_count \(trackCount) != tracks.count \(tracks.count)")
        }

        var seen = Set<String>()
        for track in tracks {
            if track.id.isEmpty {
                issues.append("track has empty id")
            }
            if !seen.insert(track.id).inserted {
                issues.append("duplicate track id: \(track.id)")
            }
            if !["tracks", "to_curate", "other"].contains(track.source) {
                issues.append("unexpected source for \(track.id): \(track.source)")
            }
            if let energy = track.energy, !(0...1).contains(energy) {
                issues.append("energy out of range for \(track.id): \(energy)")
            }
            if let bpm = track.bpm, !(70...180).contains(bpm) {
                issues.append("bpm out of map range for \(track.id): \(bpm)")
            }
            let waveformArrays = [
                track.waveformPeak,
                track.waveformLow,
                track.waveformMid,
                track.waveformHigh
            ].compactMap { $0 }
            if !waveformArrays.isEmpty {
                let counts = Set(waveformArrays.map(\.count))
                if counts.count > 1 {
                    issues.append("waveform arrays have different lengths for \(track.id)")
                }
            }
        }

        let ids = Set(tracks.map(\.id))
        for edge in edges {
            if !ids.contains(edge.source) {
                issues.append("edge source not found: \(edge.source)")
            }
            if !ids.contains(edge.target) {
                issues.append("edge target not found: \(edge.target)")
            }
            if !(0...1).contains(edge.score) {
                issues.append("edge score out of range: \(edge.score)")
            }
        }

        return issues
    }
}

public struct SetaTrack: Decodable, Identifiable, Equatable {
    public let id: String
    public let path: String
    public let artist: String?
    public let title: String?
    public let source: String
    public let genre: String?
    public let batch: String?
    public let durationSec: Double?
    public let bpm: Double?
    public let bpmRaw: Double?
    public let bpmOctaveCorrected: Bool?
    public let bpmSource: String?
    public let bpmConfidence: Double?
    public let key: String?
    public let energy: Double?
    public let vocals: String?
    public let vocalsConfidence: Double?
    public let analysisError: String?
    public let waveformVersion: Int?
    public let waveformPeak: [Double]?
    public let waveformLow: [Double]?
    public let waveformMid: [Double]?
    public let waveformHigh: [Double]?

    enum CodingKeys: String, CodingKey {
        case id
        case path
        case artist
        case title
        case source
        case genre
        case batch
        case durationSec = "duration_sec"
        case bpm
        case bpmRaw = "bpm_raw"
        case bpmOctaveCorrected = "bpm_octave_corrected"
        case bpmSource = "bpm_source"
        case bpmConfidence = "bpm_confidence"
        case key
        case energy
        case vocals
        case vocalsConfidence = "vocals_confidence"
        case analysisError = "analysis_error"
        case waveformVersion = "waveform_version"
        case waveformPeak = "waveform_peak"
        case waveformLow = "waveform_low"
        case waveformMid = "waveform_mid"
        case waveformHigh = "waveform_high"
    }

    public var displayTitle: String {
        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanTitle?.isEmpty == false ? cleanTitle! : "Unknown title"
    }

    public var displayArtist: String {
        let cleanArtist = artist?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanArtist?.isEmpty == false ? cleanArtist! : "Unknown artist"
    }
}

public struct SetaEdge: Decodable, Equatable {
    public let source: String
    public let target: String
    public let score: Double
}


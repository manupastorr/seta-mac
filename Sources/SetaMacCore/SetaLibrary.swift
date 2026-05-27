import Foundation

public struct SetaLibrary: Decodable, Equatable, Sendable {
    public let generatedAt: String?
    public let tracksRoot: String?
    public let curateRoot: String?
    public let tracksRoots: [String]?
    public let curateRoots: [String]?
    public let trackCount: Int
    public let tracks: [SetaTrack]
    public let edges: [SetaEdge]

    public init(
        generatedAt: String? = nil,
        tracksRoot: String? = nil,
        curateRoot: String? = nil,
        tracksRoots: [String]? = nil,
        curateRoots: [String]? = nil,
        trackCount: Int,
        tracks: [SetaTrack],
        edges: [SetaEdge]
    ) {
        self.generatedAt = generatedAt
        self.tracksRoot = tracksRoot
        self.curateRoot = curateRoot
        self.tracksRoots = tracksRoots
        self.curateRoots = curateRoots
        self.trackCount = trackCount
        self.tracks = tracks
        self.edges = edges
    }

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case tracksRoot = "tracks_root"
        case curateRoot = "curate_root"
        case tracksRoots = "tracks_roots"
        case curateRoots = "curate_roots"
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
            if !(0...1).contains(track.effectiveEnergy) {
                issues.append("effective energy out of range for \(track.id): \(track.effectiveEnergy)")
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

public struct SetaTrack: Decodable, Identifiable, Equatable, Sendable {
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
    public let energyAuto: Double?
    public let energyEffective: Double?
    public let energyManual: Double?
    public let energyMain: Double?
    public let energyAvg: Double?
    public let energyPeak: Double?
    public let energyIntro: Double?
    public let energyOutro: Double?
    public let energyConfidence: Double?
    public let energyCurve: [Double]?
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
        case energyAuto = "energy_auto"
        case energyEffective = "energy_effective"
        case energyManual = "energy_manual"
        case energyMain = "energy_main"
        case energyAvg = "energy_avg"
        case energyPeak = "energy_peak"
        case energyIntro = "energy_intro"
        case energyOutro = "energy_outro"
        case energyConfidence = "energy_confidence"
        case energyCurve = "energy_curve"
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

    public var effectiveEnergy: Double {
        for value in [energyManual, energyEffective, energyAuto, energyMain, energy] {
            if let value, value.isFinite {
                return min(1, max(0, value))
            }
        }
        return 0.5
    }

    public func applyingManualEnergy(_ value: Double?) -> SetaTrack {
        applyingTrackOverride(TrackOverride(energy: value))
    }

    public func applyingTrackOverride(_ override: TrackOverride?) -> SetaTrack {
        guard let override, !override.isEmpty else { return self }

        let manualEnergy = override.energy.map { min(1, max(0, $0)) }
        let effectiveEnergy = manualEnergy ?? [energyAuto, energyMain, energy].compactMap { $0 }.first ?? 0.5
        let effectiveBPM = override.bpm ?? bpm
        let effectiveKey = override.key ?? key

        return SetaTrack(
            id: id,
            path: path,
            artist: artist,
            title: title,
            source: source,
            genre: genre,
            batch: batch,
            durationSec: durationSec,
            bpm: effectiveBPM,
            bpmRaw: bpmRaw,
            bpmOctaveCorrected: bpmOctaveCorrected,
            bpmSource: bpmSource,
            bpmConfidence: bpmConfidence,
            key: effectiveKey,
            energy: energy,
            energyAuto: energyAuto,
            energyEffective: effectiveEnergy,
            energyManual: manualEnergy,
            energyMain: energyMain,
            energyAvg: energyAvg,
            energyPeak: energyPeak,
            energyIntro: energyIntro,
            energyOutro: energyOutro,
            energyConfidence: energyConfidence,
            energyCurve: energyCurve,
            vocals: vocals,
            vocalsConfidence: vocalsConfidence,
            analysisError: analysisError,
            waveformVersion: waveformVersion,
            waveformPeak: waveformPeak,
            waveformLow: waveformLow,
            waveformMid: waveformMid,
            waveformHigh: waveformHigh
        )
    }
}

public struct SetaEdge: Decodable, Equatable, Sendable {
    public let source: String
    public let target: String
    public let score: Double
}

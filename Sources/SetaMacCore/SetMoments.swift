import Foundation

public struct SetMoment: Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public let bpmRange: ClosedRange<Double>
    public let energyRange: ClosedRange<Double>
    public let colorHex: String

    public init(
        id: String,
        label: String,
        bpmRange: ClosedRange<Double>,
        energyRange: ClosedRange<Double>,
        colorHex: String
    ) {
        self.id = id
        self.label = label
        self.bpmRange = bpmRange
        self.energyRange = energyRange
        self.colorHex = colorHex
    }
}

public enum SetMoments {
    public static let all: [SetMoment] = [
        SetMoment(id: "close-eyes", label: "Close eyes", bpmRange: 70...98, energyRange: 0.05...0.42, colorHex: "#7986CB"),
        SetMoment(id: "chill-groove", label: "Chill groove", bpmRange: 88...112, energyRange: 0.35...0.58, colorHex: "#AED581"),
        SetMoment(id: "slow-burn", label: "Slow burn", bpmRange: 70...100, energyRange: 0.43...0.88, colorHex: "#FFAB91"),
        SetMoment(id: "warmup", label: "Warm up", bpmRange: 80...118, energyRange: 0.05...0.58, colorHex: "#5B8DEF"),
        SetMoment(id: "playful", label: "Playful", bpmRange: 108...134, energyRange: 0.40...0.74, colorHex: "#6FBF73"),
        SetMoment(id: "groove", label: "Groove", bpmRange: 80...124, energyRange: 0.50...0.82, colorHex: "#FFB74D"),
        SetMoment(id: "peak", label: "Peak", bpmRange: 112...142, energyRange: 0.56...0.95, colorHex: "#E57373"),
        SetMoment(id: "hypnotic", label: "Hypnotic", bpmRange: 128...180, energyRange: 0.30...0.72, colorHex: "#4DB6AC"),
        SetMoment(id: "hard", label: "Hard / driving", bpmRange: 126...180, energyRange: 0.66...1.0, colorHex: "#9575CD"),
        SetMoment(id: "minimal", label: "Strip-back", bpmRange: 118...180, energyRange: 0.05...0.38, colorHex: "#B0BEC5"),
        SetMoment(id: "closing", label: "Closing", bpmRange: 92...126, energyRange: 0.05...0.50, colorHex: "#90A4AE")
    ]

    public static let sections: [(label: String, ids: [String])] = [
        ("Open / low", ["close-eyes", "chill-groove", "slow-burn", "warmup"]),
        ("Floor", ["playful", "groove", "peak"]),
        ("Late", ["hypnotic", "hard", "minimal"]),
        ("Wind-down", ["closing"])
    ]

    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func moment(id: String) -> SetMoment? {
        byID[id]
    }

    public static func matches(_ track: SetaTrack, moment: SetMoment) -> Bool {
        guard let bpm = track.bpm else { return false }
        let energy = track.effectiveEnergy
        return moment.bpmRange.contains(bpm) && moment.energyRange.contains(energy)
    }

    public static func matchesAnyActiveMoments(_ track: SetaTrack, activeMomentIDs: Set<String>) -> Bool {
        guard !activeMomentIDs.isEmpty else { return true }
        for id in activeMomentIDs {
            guard let moment = moment(id: id) else { continue }
            if matches(track, moment: moment) { return true }
        }
        return false
    }
}

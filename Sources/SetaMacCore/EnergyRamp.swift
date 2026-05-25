import CoreGraphics
import Foundation

public struct EnergyRampPoint: Equatable, Sendable {
    public let x: CGFloat
    public let y: CGFloat
    public let trackID: String

    public init(x: CGFloat, y: CGFloat, trackID: String) {
        self.x = x
        self.y = y
        self.trackID = trackID
    }
}

public struct EnergyRampGeometry: Equatable, Sendable {
    public let path: String
    public let points: [EnergyRampPoint]
    public let minEnergy: Double
    public let maxEnergy: Double

    public init(path: String, points: [EnergyRampPoint], minEnergy: Double, maxEnergy: Double) {
        self.path = path
        self.points = points
        self.minEnergy = minEnergy
        self.maxEnergy = maxEnergy
    }
}

public enum EnergyRamp {
    public static func geometry(
        tracks: [SetaTrack],
        width: CGFloat = 220,
        height: CGFloat = 36,
        pad: CGFloat = 3
    ) -> EnergyRampGeometry {
        guard !tracks.isEmpty else {
            return EnergyRampGeometry(path: "", points: [], minEnergy: 0, maxEnergy: 0)
        }

        let energies = tracks.map(\.effectiveEnergy)
        let minEnergy = energies.min() ?? 0
        let maxEnergy = energies.max() ?? 0
        let span = Swift.max(maxEnergy - minEnergy, 0.08)
        let innerW = width - pad * 2
        let innerH = height - pad * 2

        let points = tracks.enumerated().map { index, track -> EnergyRampPoint in
            let x: CGFloat
            if tracks.count == 1 {
                x = pad + innerW / 2
            } else {
                x = pad + (CGFloat(index) / CGFloat(tracks.count - 1)) * innerW
            }
            let energy = track.effectiveEnergy
            let y = pad + innerH - CGFloat((energy - minEnergy) / span) * innerH
            return EnergyRampPoint(x: x, y: y, trackID: track.id)
        }

        let path = points.enumerated().map { index, point in
            let command = index == 0 ? "M" : "L"
            return "\(command)\(String(format: "%.1f", point.x)),\(String(format: "%.1f", point.y))"
        }.joined(separator: " ")

        return EnergyRampGeometry(path: path, points: points, minEnergy: minEnergy, maxEnergy: maxEnergy)
    }
}

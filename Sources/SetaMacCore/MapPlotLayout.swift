import CoreGraphics
import Foundation

public enum MapPlotMetrics {
    public static let bpmDomain: ClosedRange<Double> = 70 ... 180
    public static let energyDomain: ClosedRange<Double> = 0 ... 1

    public enum Margin {
        public static let top: CGFloat = 44
        public static let right: CGFloat = 36
        public static let bottom: CGFloat = 56
        public static let left: CGFloat = 64
    }

    public enum Inset {
        public static let left: CGFloat = 52
        public static let right: CGFloat = 36
        public static let top: CGFloat = 52
        public static let bottom: CGFloat = 58
    }
}

public enum EnergyDisplay {
    public static let floor = 0.15
    public static let minSpan = 0.4
    public static let percentileLo = 3.0
    public static let padRatio = 0.08
    public static let top = 1.0
    public static let fallback: ClosedRange<Double> = 0.2 ... 1.0
}

public struct MapPlotLayout: Equatable, Sendable {
    public let canvasWidth: CGFloat
    public let canvasHeight: CGFloat
    public let plotLeft: CGFloat
    public let plotWidth: CGFloat
    public let plotHeight: CGFloat
    public let energyDomain: ClosedRange<Double>

    public init(
        canvasSize: CGSize,
        mixDockWidth: CGFloat = 0,
        bottomChrome: CGFloat = 82,
        energyDomain: ClosedRange<Double> = MapPlotMetrics.energyDomain
    ) {
        canvasWidth = canvasSize.width
        canvasHeight = max(canvasSize.height, 200)
        plotLeft = mixDockWidth + MapPlotMetrics.Margin.left
        plotWidth = max(120, canvasWidth - plotLeft - MapPlotMetrics.Margin.right)
        plotHeight = max(
            120,
            canvasHeight - MapPlotMetrics.Margin.top - MapPlotMetrics.Margin.bottom - bottomChrome
        )
        self.energyDomain = energyDomain
    }

    public static func computeEnergyDisplayDomain(tracks: [SetaTrack]) -> ClosedRange<Double> {
        let energies = tracks.map(\.effectiveEnergy).filter(\.isFinite)
        guard energies.count >= 2 else { return EnergyDisplay.fallback }

        let sorted = energies.sorted()
        let hi = EnergyDisplay.top
        let pHi = energyPercentile(sorted, percentile: 97)
        var lo = energyPercentile(sorted, percentile: EnergyDisplay.percentileLo)
        let pad = max(0.02, (pHi - lo) * EnergyDisplay.padRatio)
        lo = max(EnergyDisplay.floor, lo - pad)

        var lower = lo
        if hi - lower < EnergyDisplay.minSpan {
            lower = max(EnergyDisplay.floor, hi - EnergyDisplay.minSpan)
        }

        let roundedLo = (lower * 1000).rounded() / 1000
        return roundedLo ... hi
    }

    public static func energyPercentile(_ sorted: [Double], percentile: Double) -> Double {
        guard !sorted.isEmpty else { return 0.5 }
        let index = min(
            sorted.count - 1,
            max(0, Int((percentile / 100 * Double(sorted.count - 1)).rounded()))
        )
        return sorted[index]
    }

    public func energyAxisTicks() -> [Double] {
        let lo = energyDomain.lowerBound
        let hi = energyDomain.upperBound
        let mid = (lo + hi) / 2
        let values = [lo, mid, hi, EnergyDisplay.top]
            .map { ($0 * 100).rounded() / 100 }
        return Array(Set(values)).sorted()
    }

    public func energyRangeLabel() -> String {
        let lo = energyDomain.lowerBound
        let hi = energyDomain.upperBound
        if lo <= 0.001, hi >= 0.999 {
            return "Intensity (est.) →"
        }
        return String(format: "Intensity %.2f–%.1f →", lo, hi)
    }

    public func bpmX(_ bpm: Double) -> CGFloat {
        let xMin = MapPlotMetrics.Inset.left
        let xMax = plotWidth - MapPlotMetrics.Inset.right
        let ratio = normalized(bpm, in: MapPlotMetrics.bpmDomain)
        return xMin + CGFloat(ratio) * (xMax - xMin)
    }

    public func energyY(_ energy: Double) -> CGFloat {
        let yMin = MapPlotMetrics.Inset.top
        let yMax = plotHeight - MapPlotMetrics.Inset.bottom
        let ratio = normalized(energy, in: energyDomain)
        return yMax - CGFloat(ratio) * (yMax - yMin)
    }

    public func trackPoint(for track: SetaTrack, jitter: Bool = true) -> CGPoint {
        let cx: CGFloat
        if let bpm = track.bpm {
            cx = bpmX(bpm)
        } else {
            let mid = (MapPlotMetrics.bpmDomain.lowerBound + MapPlotMetrics.bpmDomain.upperBound) / 2
            cx = bpmX(mid)
        }
        let cy = energyY(track.effectiveEnergy)
        var px = cx
        var py = cy
        if jitter {
            let (jx, jy) = MapPlotLayout.stableJitter(id: track.id)
            px += jx
            py += jy
        }
        return boundToPlot(x: px, y: py, id: track.id)
    }

    public func momentEllipse(_ moment: SetMoment) -> (cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) {
        let bpmMid = (moment.bpmRange.lowerBound + moment.bpmRange.upperBound) / 2
        let energyMid = (moment.energyRange.lowerBound + moment.energyRange.upperBound) / 2
        let cx = bpmX(bpmMid)
        let cy = energyY(energyMid)
        let rx = max(18, (bpmX(moment.bpmRange.upperBound) - bpmX(moment.bpmRange.lowerBound)) / 2 * 0.92)
        let ry = max(
            14,
            abs(energyY(moment.energyRange.lowerBound) - energyY(moment.energyRange.upperBound)) / 2 * 0.92
        )
        return (cx, cy, rx, ry)
    }

    public func momentBelowDisplayView(_ moment: SetMoment) -> Bool {
        moment.energyRange.upperBound < energyDomain.lowerBound + 0.02
    }

    public func plotOrigin(in canvas: CGSize) -> CGPoint {
        CGPoint(x: plotLeft, y: MapPlotMetrics.Margin.top)
    }

    public func canvasPoint(for track: SetaTrack, jitter: Bool = true) -> CGPoint {
        let local = trackPoint(for: track, jitter: jitter)
        let origin = plotOrigin(in: CGSize(width: canvasWidth, height: canvasHeight))
        return CGPoint(x: origin.x + local.x, y: origin.y + local.y)
    }

    public func nearestTrack(
        to location: CGPoint,
        tracks: [SetaTrack],
        pickRadius: CGFloat = 10
    ) -> SetaTrack? {
        let origin = plotOrigin(in: CGSize(width: canvasWidth, height: canvasHeight))
        let local = CGPoint(x: location.x - origin.x, y: location.y - origin.y)
        return tracks
            .compactMap { track -> (SetaTrack, CGFloat)? in
                let point = trackPoint(for: track, jitter: true)
                return (track, hypot(point.x - local.x, point.y - local.y))
            }
            .filter { $0.1 <= pickRadius }
            .min { $0.1 < $1.1 }?
            .0
    }

    public static func stableJitter(id: String, ampX: CGFloat = 28, ampY: CGFloat = 18) -> (CGFloat, CGFloat) {
        var hash: UInt32 = 2_166_136_261
        for scalar in id.unicodeScalars {
            hash ^= scalar.value
            hash = hash &* 1_677_7619
        }
        let angle = CGFloat((hash & 0xffff)) / CGFloat(0xffff) * .pi * 2
        let radius = CGFloat((hash >> 16) & 0xffff) / CGFloat(0xffff)
        let jx = cos(angle) * radius * ampX
        var jy = sin(angle) * radius * ampY
        if jy >= 0 { jy *= 0.55 }
        return (jx, jy)
    }

    private func boundToPlot(x: CGFloat, y: CGFloat, id: String) -> CGPoint {
        let minX: CGFloat = 6
        let maxX = plotWidth - 6
        let minY = MapPlotMetrics.Inset.top
        let maxY = plotHeight - MapPlotMetrics.Inset.bottom
        return CGPoint(
            x: softBound(x, min: minX, max: maxX, salt: "\(id):x"),
            y: softBound(y, min: minY, max: maxY, salt: "\(id):y")
        )
    }

    private func softBound(_ value: CGFloat, min: CGFloat, max: CGFloat, salt: String) -> CGFloat {
        if value >= min, value <= max { return value }
        let jitter = abs(MapPlotLayout.stableJitter(id: salt, ampX: 14, ampY: 14).0)
        if value < min { return min + jitter * 0.65 }
        return max - jitter * 0.65
    }

    private func normalized(_ value: Double, in domain: ClosedRange<Double>) -> Double {
        (value - domain.lowerBound) / (domain.upperBound - domain.lowerBound)
    }
}

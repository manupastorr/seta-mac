import CoreGraphics
import Foundation

public enum MapPlotMetrics {
    public static let bpmDomain: ClosedRange<Double> = 70 ... 180
    public static let energyDomain: ClosedRange<Double> = 0 ... 1

    public enum Margin {
        public static let top: CGFloat = 12
        public static let right: CGFloat = 36
        public static let bottom: CGFloat = 56
        public static let left: CGFloat = 64
    }

    public enum Inset {
        public static let left: CGFloat = 52
        public static let right: CGFloat = 36
        public static let top: CGFloat = 32
        public static let bottom: CGFloat = 58
    }
}

public enum EnergyDisplay {
    public static let floor = 0.15
    public static let minSpan = 0.4
    public static let percentileLo = 3.0
    public static let percentileHi = 97.0
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
    public let topChrome: CGFloat
    public let energyDomain: ClosedRange<Double>

    public init(
        canvasSize: CGSize,
        mixDockWidth: CGFloat = 0,
        rightChrome: CGFloat = 0,
        topChrome: CGFloat = 0,
        bottomChrome: CGFloat = 82,
        energyDomain: ClosedRange<Double> = MapPlotMetrics.energyDomain
    ) {
        canvasWidth = canvasSize.width
        canvasHeight = max(canvasSize.height, 200)
        self.topChrome = topChrome
        plotLeft = mixDockWidth + MapPlotMetrics.Margin.left
        plotWidth = max(120, canvasWidth - plotLeft - MapPlotMetrics.Margin.right - rightChrome)
        plotHeight = max(
            120,
            canvasHeight
                - topChrome
                - MapPlotMetrics.Margin.top
                - MapPlotMetrics.Margin.bottom
                - bottomChrome
        )
        self.energyDomain = energyDomain
    }

    public static func computeEnergyDisplayDomain(tracks: [SetaTrack]) -> ClosedRange<Double> {
        let energies = tracks.map(\.effectiveEnergy).filter(\.isFinite)
        guard energies.count >= 2 else { return EnergyDisplay.fallback }

        let sorted = energies.sorted()
        let pHi = energyPercentile(sorted, percentile: EnergyDisplay.percentileHi)
        let maxEnergy = sorted.last!
        var lo = energyPercentile(sorted, percentile: EnergyDisplay.percentileLo)
        let pad = max(0.02, (pHi - lo) * EnergyDisplay.padRatio)
        lo = max(EnergyDisplay.floor, lo - pad)
        // Cap the top at real library data so the plot does not reserve empty space up to 1.0.
        var hi = min(EnergyDisplay.top, max(maxEnergy, pHi) + pad)

        if hi - lo < EnergyDisplay.minSpan {
            hi = min(EnergyDisplay.top, lo + EnergyDisplay.minSpan)
            lo = max(EnergyDisplay.floor, hi - EnergyDisplay.minSpan)
        }

        let roundedLo = (lo * 1000).rounded() / 1000
        let roundedHi = (hi * 1000).rounded() / 1000
        return roundedLo ... roundedHi
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
        let values = [lo, mid, hi]
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

    public enum DisplayLayout {
        public static let collisionIterations = 22
        public static let maxDisplacement: CGFloat = 24
        public static let separationPadding: CGFloat = 1.25
    }

    public func anchorPoint(for track: SetaTrack) -> CGPoint {
        let cx: CGFloat
        if let bpm = track.bpm {
            cx = bpmX(bpm)
        } else {
            let mid = (MapPlotMetrics.bpmDomain.lowerBound + MapPlotMetrics.bpmDomain.upperBound) / 2
            cx = bpmX(mid)
        }
        let cy = energyY(track.effectiveEnergy)
        return boundToPlot(x: cx, y: cy, id: track.id)
    }

    /// Plot position for drawing and hit-testing. Uses collision-resolved layout when provided.
    public func trackPoint(for track: SetaTrack, displayPositions: [String: CGPoint]? = nil) -> CGPoint {
        if let resolved = displayPositions?[track.id] {
            return resolved
        }
        return anchorPoint(for: track)
    }

    @available(*, deprecated, message: "Use trackPoint(for:displayPositions:) with resolveDisplayPositions")
    public func trackPoint(for track: SetaTrack, jitter: Bool) -> CGPoint {
        if jitter {
            let anchor = anchorPoint(for: track)
            let (jx, jy) = MapPlotLayout.stableJitter(id: track.id)
            return boundToPlot(x: anchor.x + jx, y: anchor.y + jy, id: track.id)
        }
        return anchorPoint(for: track)
    }

    public func resolveDisplayPositions(for tracks: [SetaTrack]) -> [String: CGPoint] {
        struct Node {
            let id: String
            let anchor: CGPoint
            let radius: CGFloat
        }

        var nodes: [Node] = []
        nodes.reserveCapacity(tracks.count)
        for track in tracks {
            guard track.bpm != nil else { continue }
            nodes.append(
                Node(
                    id: track.id,
                    anchor: anchorPoint(for: track),
                    radius: TrackPresentation.nodeRadius(for: track)
                )
            )
        }

        guard !nodes.isEmpty else { return [:] }

        var positions = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.anchor) })
        let maxDisp = DisplayLayout.maxDisplacement
        let pad = DisplayLayout.separationPadding

        for _ in 0 ..< DisplayLayout.collisionIterations {
            for i in 0 ..< nodes.count {
                for j in (i + 1) ..< nodes.count {
                    let nodeA = nodes[i]
                    let nodeB = nodes[j]
                    var a = positions[nodeA.id]!
                    var b = positions[nodeB.id]!
                    let minSep = nodeA.radius + nodeB.radius + pad
                    var dx = b.x - a.x
                    var dy = b.y - a.y
                    var dist = hypot(dx, dy)
                    if dist < 0.001 {
                        dist = 0.001
                        dx = 0.001
                        dy = 0
                    }
                    guard dist < minSep else { continue }
                    let push = (minSep - dist) / 2
                    let nx = dx / dist
                    let ny = dy / dist
                    a.x -= nx * push
                    a.y -= ny * push
                    b.x += nx * push
                    b.y += ny * push
                    positions[nodeA.id] = capDisplacement(
                        point: a,
                        anchor: nodeA.anchor,
                        max: maxDisp,
                        id: nodeA.id
                    )
                    positions[nodeB.id] = capDisplacement(
                        point: b,
                        anchor: nodeB.anchor,
                        max: maxDisp,
                        id: nodeB.id
                    )
                }
            }
        }

        return positions
    }

    private func capDisplacement(point: CGPoint, anchor: CGPoint, max: CGFloat, id: String) -> CGPoint {
        let dx = point.x - anchor.x
        let dy = point.y - anchor.y
        let distance = hypot(dx, dy)
        if distance <= max {
            return boundToPlot(x: point.x, y: point.y, id: id)
        }
        let scale = max / distance
        return boundToPlot(
            x: anchor.x + dx * scale,
            y: anchor.y + dy * scale,
            id: id
        )
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
        CGPoint(x: plotLeft, y: topChrome + MapPlotMetrics.Margin.top)
    }

    public func canvasPoint(
        for track: SetaTrack,
        displayPositions: [String: CGPoint]? = nil
    ) -> CGPoint {
        let local = trackPoint(for: track, displayPositions: displayPositions)
        let origin = plotOrigin(in: CGSize(width: canvasWidth, height: canvasHeight))
        return CGPoint(x: origin.x + local.x, y: origin.y + local.y)
    }

    public func tracksNear(
        to location: CGPoint,
        tracks: [SetaTrack],
        pickRadius: CGFloat = 10,
        displayPositions: [String: CGPoint]? = nil
    ) -> [SetaTrack] {
        let origin = plotOrigin(in: CGSize(width: canvasWidth, height: canvasHeight))
        let local = CGPoint(x: location.x - origin.x, y: location.y - origin.y)
        return tracks
            .compactMap { track -> (SetaTrack, CGFloat)? in
                let point = trackPoint(for: track, displayPositions: displayPositions)
                let distance = hypot(point.x - local.x, point.y - local.y)
                guard distance <= pickRadius else { return nil }
                return (track, distance)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    public func nearestTrack(
        to location: CGPoint,
        tracks: [SetaTrack],
        pickRadius: CGFloat = 10,
        displayPositions: [String: CGPoint]? = nil
    ) -> SetaTrack? {
        tracksNear(
            to: location,
            tracks: tracks,
            pickRadius: pickRadius,
            displayPositions: displayPositions
        ).first
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

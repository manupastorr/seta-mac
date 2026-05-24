import SwiftUI
import SetaMacCore

struct TrackMapView: View {
    let tracks: [SetaTrack]
    @Binding var selectedTrackID: String?
    @Binding var hoveredTrackID: String?
    var playingTrackID: String?
    var neighborHighlightIDs: Set<String> = []
    var neighborAnchorID: String?
    var draftTrackIDs: Set<String> = []
    var draftFinalIDs: Set<String> = []
    var graphEdges: [(SetaTrack, SetaTrack, Double)] = []
    var mixLinks: [(SetaTrack, SetaTrack)] = []
    var showExploreLayout: Bool = false
    var showSetZoneOverlay: Bool = true
    var activeMomentIDs: Set<String> = []
    var energyDomain: ClosedRange<Double> = MapPlotMetrics.energyDomain
    var mixDockWidth: CGFloat = 0
    var bottomChrome: CGFloat = SetaTheme.playerHeight + 10
    var resetTrigger: UUID = UUID()
    var onPlayTrack: ((String) -> Void)?

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var panBase: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let layout = MapPlotLayout(
                canvasSize: proxy.size,
                mixDockWidth: mixDockWidth,
                bottomChrome: bottomChrome,
                energyDomain: energyDomain
            )
            let origin = layout.plotOrigin(in: proxy.size)

            ZStack(alignment: .topLeading) {
                mapCanvas(layout: layout, origin: origin, size: proxy.size)
                    .scaleEffect(scale)
                    .offset(offset)

                axisOverlay(layout: layout, origin: origin)

                if let hoveredID = hoveredTrackID,
                   let hovered = tracks.first(where: { $0.id == hoveredID }) {
                    tooltipOverlay(for: hovered, layout: layout, origin: origin, canvasSize: proxy.size)
                    loupeOverlay(for: hovered, layout: layout, origin: origin, canvasSize: proxy.size)
                }
            }
            .background(SetaTheme.background)
            .gesture(magnifyGesture)
            .simultaneousGesture(panGesture)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard hypot(value.translation.width, value.translation.height) < 6 else { return }
                        guard scale <= 1.01, offset == .zero else { return }
                        let mapped = inverseMapPoint(value.location, origin: origin)
                        if let track = layout.nearestTrack(to: mapped, tracks: tracks) {
                            selectedTrackID = track.id
                            onPlayTrack?(track.id)
                        } else {
                            hoveredTrackID = nil
                        }
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    guard scale <= 1.01, offset == .zero else {
                        hoveredTrackID = nil
                        return
                    }
                    let mapped = inverseMapPoint(location, origin: origin)
                    hoveredTrackID = layout.nearestTrack(to: mapped, tracks: tracks)?.id
                case .ended:
                    hoveredTrackID = nil
                }
            }
        }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in scale = min(4, max(1, lastScale * value)) }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.01 { resetView() }
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard scale > 1.01 else { return }
                offset = CGSize(
                    width: panBase.width + value.translation.width,
                    height: panBase.height + value.translation.height
                )
            }
            .onEnded { _ in panBase = offset }
    }

    private func resetView() {
        scale = 1
        lastScale = 1
        offset = .zero
        panBase = .zero
    }

    private func inverseMapPoint(_ location: CGPoint, origin: CGPoint) -> CGPoint {
        let center = CGPoint(x: origin.x, y: origin.y)
        let translated = CGPoint(x: location.x - offset.width, y: location.y - offset.height)
        let unscaled = CGPoint(
            x: center.x + (translated.x - center.x) / scale,
            y: center.y + (translated.y - center.y) / scale
        )
        return CGPoint(x: unscaled.x - origin.x, y: unscaled.y - origin.y)
    }

    @ViewBuilder
    private func mapCanvas(layout: MapPlotLayout, origin: CGPoint, size: CGSize) -> some View {
        Canvas { context, _ in
            context.translateBy(x: origin.x, y: origin.y)
            drawGrid(context: &context, layout: layout)
            if showSetZoneOverlay {
                drawSetMoments(context: &context, layout: layout)
            }
            if showExploreLayout {
                drawGraphEdges(context: &context, layout: layout)
            }
            drawMixLinks(context: &context, layout: layout)
            drawTracks(context: &context, layout: layout)
        }
        .onChange(of: resetTrigger) { _, _ in resetView() }
    }

    @ViewBuilder
    private func axisOverlay(layout: MapPlotLayout, origin: CGPoint) -> some View {
        ZStack(alignment: .topLeading) {
            Text("BPM →")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SetaTheme.muted)
                .position(x: origin.x + layout.plotWidth / 2, y: origin.y + layout.plotHeight + 40)

            Text(layout.energyRangeLabel())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SetaTheme.muted)
                .rotationEffect(.degrees(-90))
                .position(x: origin.x - 34, y: origin.y + layout.plotHeight / 2)

            ForEach(Array(stride(from: Int(MapPlotMetrics.bpmDomain.lowerBound), through: Int(MapPlotMetrics.bpmDomain.upperBound), by: 20)), id: \.self) { bpm in
                Text("\(bpm)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(SetaTheme.muted.opacity(0.8))
                    .position(x: origin.x + layout.bpmX(Double(bpm)), y: origin.y + layout.plotHeight + 18)
            }

            ForEach(Array(layout.energyAxisTicks().enumerated()), id: \.offset) { _, tick in
                Text(String(format: "%.1f", tick))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(SetaTheme.muted.opacity(0.8))
                    .position(x: origin.x - 12, y: origin.y + layout.energyY(tick) + 3)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func tooltipOverlay(for track: SetaTrack, layout: MapPlotLayout, origin: CGPoint, canvasSize: CGSize) -> some View {
        let point = layout.trackPoint(for: track, jitter: true)
        let screen = CGPoint(x: origin.x + point.x + 16, y: origin.y + point.y - 12)
        TrackTooltipView(track: track)
            .position(
                x: min(max(130, screen.x), canvasSize.width - 130),
                y: min(max(80, screen.y), canvasSize.height - 120)
            )
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func loupeOverlay(for track: SetaTrack, layout: MapPlotLayout, origin: CGPoint, canvasSize: CGSize) -> some View {
        let local = layout.trackPoint(for: track, jitter: true)
        let point = transformedScreenPoint(
            local: local,
            origin: origin,
            canvasSize: canvasSize
        )
        let radius: CGFloat = 70
        let margin: CGFloat = 10
        let x = min(max(point.x, radius + margin), canvasSize.width - radius - margin)
        let y = min(max(point.y, radius + margin), canvasSize.height - radius - margin)

        MapLoupeView(
            track: track,
            layout: layout,
            tracks: tracks,
            neighborIDs: neighborHighlightIDs,
            playingID: playingTrackID
        )
        .position(x: x, y: y)
        .allowsHitTesting(false)
    }

    private func transformedScreenPoint(local: CGPoint, origin: CGPoint, canvasSize: CGSize) -> CGPoint {
        let base = CGPoint(x: origin.x + local.x, y: origin.y + local.y)
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        return CGPoint(
            x: center.x + (base.x - center.x) * scale + offset.width,
            y: center.y + (base.y - center.y) * scale + offset.height
        )
    }

    private func drawGrid(context: inout GraphicsContext, layout: MapPlotLayout) {
        var path = Path()
        let bottom = layout.plotHeight - MapPlotMetrics.Inset.bottom
        for bpm in stride(from: MapPlotMetrics.bpmDomain.lowerBound, through: MapPlotMetrics.bpmDomain.upperBound, by: 20) {
            let x = layout.bpmX(bpm)
            path.move(to: CGPoint(x: x, y: MapPlotMetrics.Inset.top))
            path.addLine(to: CGPoint(x: x, y: bottom))
        }
        for tick in layout.energyAxisTicks() {
            let y = layout.energyY(tick)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: layout.plotWidth, y: y))
        }
        context.stroke(path, with: .color(.black.opacity(0.04)), lineWidth: 0.5)
    }

    private func drawSetMoments(context: inout GraphicsContext, layout: MapPlotLayout) {
        let filtering = !activeMomentIDs.isEmpty
        let tickBandTop = layout.plotHeight - MapPlotMetrics.Inset.bottom - 8

        for moment in SetMoments.all {
            let ellipse = layout.momentEllipse(moment)
            let active = activeMomentIDs.isEmpty || activeMomentIDs.contains(moment.id)
            let belowView = layout.momentBelowDisplayView(moment)
            var fillOpacity = filtering ? (active ? 0.12 : 0.02) : 0.045
            if belowView { fillOpacity *= 0.45 }

            let rect = CGRect(x: ellipse.cx - ellipse.rx, y: ellipse.cy - ellipse.ry, width: ellipse.rx * 2, height: ellipse.ry * 2)
            for blurPass in 0 ..< 4 {
                let expansion = CGFloat(blurPass + 1) * 3
                let blurRect = rect.insetBy(dx: -expansion, dy: -expansion)
                context.fill(
                    Path(ellipseIn: blurRect),
                    with: .color(Color(hex: moment.colorHex).opacity(fillOpacity * 0.18))
                )
            }
            context.fill(Path(ellipseIn: rect), with: .color(Color(hex: moment.colorHex).opacity(fillOpacity)))

            if belowView { continue }
            let labelY = ellipse.cy - ellipse.ry - 5
            guard labelY >= 12, labelY <= tickBandTop, ellipse.cx >= 28, ellipse.cx <= layout.plotWidth - 28 else { continue }
            let labelOpacity = filtering && !active ? 0.28 : (belowView ? 0.72 : 1)
            context.draw(
                Text(moment.label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1e1e2d").opacity(0.32 * labelOpacity)),
                at: CGPoint(x: ellipse.cx, y: labelY),
                anchor: .center
            )
        }
    }

    private func drawGraphEdges(context: inout GraphicsContext, layout: MapPlotLayout) {
        for (source, target, score) in graphEdges {
            let start = layout.trackPoint(for: source, jitter: true)
            let end = layout.trackPoint(for: target, jitter: true)
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(
                path,
                with: .color(SetaTheme.accent.opacity(0.08 + score * 0.35)),
                lineWidth: 0.5 + score * 0.8
            )
        }
    }

    private func drawMixLinks(context: inout GraphicsContext, layout: MapPlotLayout) {
        for (source, target) in mixLinks {
            let start = layout.trackPoint(for: source, jitter: true)
            let end = layout.trackPoint(for: target, jitter: true)
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(path, with: .color(SetaTheme.accent.opacity(0.45)), lineWidth: 1.25)
        }
    }

    private func drawTracks(context: inout GraphicsContext, layout: MapPlotLayout) {
        let anchor = neighborAnchorID
        let neighbors = neighborHighlightIDs

        for track in tracks {
            guard track.bpm != nil else { continue }
            let point = layout.trackPoint(for: track, jitter: true)
            let isSelected = track.id == selectedTrackID || track.id == anchor
            let isPlaying = track.id == playingTrackID
            let isNeighbor = neighbors.contains(track.id)
            let isHovered = track.id == hoveredTrackID
            let isDraft = draftTrackIDs.contains(track.id)
            let isFinal = draftFinalIDs.contains(track.id)

            let radius = TrackPresentation.nodeRadius(for: track, hovered: isHovered)
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            var color = Color(hex: Camelot.colorHex(track.key))

            if neighbors.isEmpty {
                // full opacity
            } else if isNeighbor, !isSelected {
                color = color.opacity(0.95)
            } else if !isNeighbor, !isSelected {
                color = color.opacity(0.2)
            }

            context.fill(Path(ellipseIn: rect), with: .color(color))
            context.stroke(Path(ellipseIn: rect), with: .color(.black.opacity(0.12)), lineWidth: 0.5)

            if isDraft {
                context.stroke(
                    Path(ellipseIn: rect.insetBy(dx: -1.5, dy: -1.5)),
                    with: .color(SetaTheme.draftGold.opacity(isFinal ? 0.9 : 0.45)),
                    lineWidth: isFinal ? 1.5 : 1
                )
            }

            if isPlaying || isSelected {
                context.stroke(
                    Path(ellipseIn: rect.insetBy(dx: -2.5, dy: -2.5)),
                    with: .color(SetaTheme.accent),
                    lineWidth: isPlaying ? 1.5 : 1.25
                )
            } else if isNeighbor {
                context.stroke(
                    Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)),
                    with: .color(SetaTheme.accent.opacity(0.8)),
                    lineWidth: 1.25
                )
            }
        }
    }
}

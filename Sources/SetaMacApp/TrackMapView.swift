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
    var mixLinks: [(SetaTrack, SetaTrack)] = []
    var showSetZoneOverlay: Bool = true
    var activeMomentIDs: Set<String> = []
    var energyDomain: ClosedRange<Double> = MapPlotMetrics.energyDomain
    var mixDockWidth: CGFloat = 0
    var rightChrome: CGFloat = 0
    var bottomChrome: CGFloat = SetaTheme.playerHeight + 10
    var resetTrigger: UUID = UUID()
    var trackOverrides: [String: TrackOverride] = [:]
    var onPlayTrack: ((String) -> Void)?

    private static let maxZoom: CGFloat = 10

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var panBase: CGSize = .zero
    @State private var hoverLocation: CGPoint?
    @State private var isPanning = false
    @State private var canvasSize: CGSize = .zero
    @State private var pickMenu: MapPickMenu?

    private struct MapPickMenu: Equatable {
        let candidates: [SetaTrack]
        let screenPoint: CGPoint
    }

    private var showsLoupe: Bool {
        scale <= 1.01 && offset == .zero
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = MapPlotLayout(
                canvasSize: proxy.size,
                mixDockWidth: mixDockWidth,
                rightChrome: rightChrome,
                bottomChrome: bottomChrome,
                energyDomain: energyDomain
            )
            let displayPositions = layout.resolveDisplayPositions(for: tracks)
            let origin = layout.plotOrigin(in: proxy.size)

            ZStack(alignment: .topLeading) {
                mapCanvas(
                    layout: layout,
                    origin: origin,
                    size: proxy.size,
                    displayPositions: displayPositions
                )
                .scaleEffect(scale, anchor: .center)
                .offset(offset)

                axisOverlay(layout: layout, origin: origin)

                zoomHoverOverlay(
                    layout: layout,
                    origin: origin,
                    canvasSize: proxy.size,
                    displayPositions: displayPositions
                )

                if showsLoupe,
                   let hoveredID = hoveredTrackID,
                   let hovered = tracks.first(where: { $0.id == hoveredID }) {
                    let anchor = hoverLocation ?? transformedScreenPoint(
                        local: layout.trackPoint(for: hovered, displayPositions: displayPositions),
                        origin: origin,
                        canvasSize: proxy.size
                    )
                    loupeOverlay(
                        for: hovered,
                        layout: layout,
                        anchor: anchor,
                        canvasSize: proxy.size,
                        displayPositions: displayPositions
                    )
                    tooltipOverlay(for: hovered, anchor: anchor, canvasSize: proxy.size)
                }

                if let pickMenu {
                    MapPickDisambiguationView(
                        candidates: pickMenu.candidates,
                        anchor: pickMenu.screenPoint,
                        canvasSize: proxy.size,
                        trackOverrides: trackOverrides,
                        onSelect: { trackID in
                            self.pickMenu = nil
                            selectedTrackID = trackID
                            onPlayTrack?(trackID)
                        },
                        onDismiss: { self.pickMenu = nil }
                    )
                    .zIndex(8)
                }
            }
            .background(SetaTheme.background)
            .onAppear { canvasSize = proxy.size }
            .onChange(of: proxy.size) { _, newSize in canvasSize = newSize }
            .gesture(magnifyGesture(canvasSize: proxy.size))
            .simultaneousGesture(panGesture)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard hypot(value.translation.width, value.translation.height) < 6 else { return }
                        let location = untransformedCanvasPoint(screen: value.location, canvasSize: proxy.size)
                        let pickRadius = clickPickRadius
                        let nearby = layout.tracksNear(
                            to: location,
                            tracks: tracks,
                            pickRadius: pickRadius,
                            displayPositions: displayPositions
                        )
                        switch nearby.count {
                        case 0:
                            pickMenu = nil
                            hoveredTrackID = nil
                        case 1:
                            pickMenu = nil
                            selectedTrackID = nearby[0].id
                            onPlayTrack?(nearby[0].id)
                        default:
                            pickMenu = MapPickMenu(candidates: nearby, screenPoint: value.location)
                        }
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    guard !isPanning, pickMenu == nil else {
                        hoveredTrackID = nil
                        hoverLocation = nil
                        return
                    }
                    let canvasLocation = untransformedCanvasPoint(screen: location, canvasSize: proxy.size)
                    if let nearest = layout.nearestTrack(
                        to: canvasLocation,
                        tracks: tracks,
                        pickRadius: hoverPickRadius,
                        displayPositions: displayPositions
                    ) {
                        hoveredTrackID = nearest.id
                        hoverLocation = location
                    } else {
                        hoveredTrackID = nil
                        hoverLocation = nil
                    }
                case .ended:
                    hoveredTrackID = nil
                    hoverLocation = nil
                }
            }
        }
    }

    private var clickPickRadius: CGFloat {
        max(14, 12 / max(scale, 1))
    }

    private var hoverPickRadius: CGFloat {
        max(12, 10 / max(scale, 1))
    }

    private func magnifyGesture(canvasSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = min(Self.maxZoom, max(1, lastScale * value))
                let focal = hoverLocation ?? CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                applyZoom(from: scale, to: newScale, focalScreen: focal, canvasSize: canvasSize)
                if newScale > 1.01 { clearHover() }
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.01 { resetView() }
            }
    }

    private func applyZoom(from oldScale: CGFloat, to newScale: CGFloat, focalScreen: CGPoint, canvasSize: CGSize) {
        guard oldScale > 0.001 else {
            scale = newScale
            return
        }
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let base = untransformedCanvasPoint(screen: focalScreen, canvasSize: canvasSize)
        offset = CGSize(
            width: focalScreen.x - center.x - (base.x - center.x) * newScale,
            height: focalScreen.y - center.y - (base.y - center.y) * newScale
        )
        panBase = offset
        scale = newScale
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard scale > 1.01 else { return }
                isPanning = true
                clearHover()
                pickMenu = nil
                offset = CGSize(
                    width: panBase.width + value.translation.width,
                    height: panBase.height + value.translation.height
                )
            }
            .onEnded { _ in
                isPanning = false
                panBase = offset
            }
    }

    private func resetView() {
        scale = 1
        lastScale = 1
        offset = .zero
        panBase = .zero
        isPanning = false
        pickMenu = nil
        clearHover()
    }

    private func clearHover() {
        hoveredTrackID = nil
        hoverLocation = nil
    }

    @ViewBuilder
    private func zoomHoverOverlay(
        layout: MapPlotLayout,
        origin: CGPoint,
        canvasSize: CGSize,
        displayPositions: [String: CGPoint]
    ) -> some View {
        if !showsLoupe,
           let hoveredID = hoveredTrackID,
           let hovered = tracks.first(where: { $0.id == hoveredID }) {
            let local = layout.trackPoint(for: hovered, displayPositions: displayPositions)
            let center = transformedScreenPoint(local: local, origin: origin, canvasSize: canvasSize)
            let radius = TrackPresentation.zoomHoveredNodeRadius(for: hovered) * scale
            let fill = Color(hex: Camelot.colorHex(hovered.key))

            Circle()
                .fill(fill)
                .frame(width: radius * 2, height: radius * 2)
                .overlay {
                    Circle()
                        .strokeBorder(SetaTheme.accent, lineWidth: 1.5)
                }
                .shadow(color: fill.opacity(0.35), radius: 4, y: 1)
                .position(x: center.x, y: center.y)
                .allowsHitTesting(false)
                .zIndex(4)
        }
    }

    @ViewBuilder
    private func mapCanvas(
        layout: MapPlotLayout,
        origin: CGPoint,
        size: CGSize,
        displayPositions: [String: CGPoint]
    ) -> some View {
        Canvas { context, _ in
            context.translateBy(x: origin.x, y: origin.y)
            drawGrid(context: &context, layout: layout)
            if showSetZoneOverlay {
                drawSetMoments(context: &context, layout: layout)
            }
            drawMixLinks(context: &context, layout: layout, displayPositions: displayPositions)
            drawTracks(context: &context, layout: layout, displayPositions: displayPositions)
        }
        .id("\(hoveredTrackID ?? "")-\(scale)-\(offset.width)-\(offset.height)-\(tracks.count)")
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
    private func tooltipOverlay(for track: SetaTrack, anchor: CGPoint, canvasSize: CGSize) -> some View {
        let center = clampedLoupeCenter(anchor, canvasSize: canvasSize)
        let tooltipWidth: CGFloat = 236
        let estimatedTooltipHeight: CGFloat = 172
        let loupeRadius: CGFloat = 70
        let gap: CGFloat = 10
        let left = center.x + loupeRadius + gap
        let top = center.y - loupeRadius / 2

        TrackTooltipView(track: track, override: trackOverrides[track.id])
            .position(x: left + tooltipWidth / 2, y: top + estimatedTooltipHeight / 2)
            .allowsHitTesting(false)
            .zIndex(6)
    }

    @ViewBuilder
    private func loupeOverlay(
        for track: SetaTrack,
        layout: MapPlotLayout,
        anchor: CGPoint,
        canvasSize: CGSize,
        displayPositions: [String: CGPoint]
    ) -> some View {
        let center = clampedLoupeCenter(anchor, canvasSize: canvasSize)

        MapLoupeView(
            track: track,
            layout: layout,
            tracks: tracks,
            displayPositions: displayPositions,
            neighborIDs: neighborHighlightIDs,
            playingID: playingTrackID
        )
        .position(x: center.x, y: center.y)
        .allowsHitTesting(false)
        .zIndex(5)
    }

    private func clampedLoupeCenter(_ point: CGPoint, canvasSize: CGSize) -> CGPoint {
        let radius: CGFloat = 70
        let margin: CGFloat = 10
        return CGPoint(
            x: min(max(point.x, radius + margin), canvasSize.width - radius - margin),
            y: min(max(point.y, radius + margin), canvasSize.height - radius - margin)
        )
    }

    private func transformedScreenPoint(local: CGPoint, origin: CGPoint, canvasSize: CGSize) -> CGPoint {
        let base = CGPoint(x: origin.x + local.x, y: origin.y + local.y)
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        return CGPoint(
            x: center.x + (base.x - center.x) * scale + offset.width,
            y: center.y + (base.y - center.y) * scale + offset.height
        )
    }

    private func untransformedCanvasPoint(screen: CGPoint, canvasSize: CGSize) -> CGPoint {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        return CGPoint(
            x: center.x + (screen.x - offset.width - center.x) / scale,
            y: center.y + (screen.y - offset.height - center.y) / scale
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
            var fillOpacity = filtering ? (active ? 0.18 : 0.035) : 0.09
            if belowView { fillOpacity *= 0.45 }

            let rect = CGRect(x: ellipse.cx - ellipse.rx, y: ellipse.cy - ellipse.ry, width: ellipse.rx * 2, height: ellipse.ry * 2)
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 12))
                layer.fill(Path(ellipseIn: rect), with: .color(Color(hex: moment.colorHex).opacity(fillOpacity)))
            }

            if belowView { continue }
            let labelY = ellipse.cy
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

    private func drawMixLinks(
        context: inout GraphicsContext,
        layout: MapPlotLayout,
        displayPositions: [String: CGPoint]
    ) {
        for (source, target) in mixLinks {
            let start = layout.trackPoint(for: source, displayPositions: displayPositions)
            let end = layout.trackPoint(for: target, displayPositions: displayPositions)
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(path, with: .color(SetaTheme.accent.opacity(0.45)), lineWidth: 1.25)
        }
    }

    private func drawTracks(
        context: inout GraphicsContext,
        layout: MapPlotLayout,
        displayPositions: [String: CGPoint]
    ) {
        let anchor = neighborAnchorID
        let neighbors = neighborHighlightIDs
        let skipHoveredInCanvas = !showsLoupe && hoveredTrackID != nil

        for track in tracks {
            guard track.bpm != nil else { continue }
            if skipHoveredInCanvas, track.id == hoveredTrackID { continue }
            drawTrackNode(
                context: &context,
                layout: layout,
                track: track,
                displayPositions: displayPositions,
                anchor: anchor,
                neighbors: neighbors,
                zoomHighlight: false
            )
        }
    }

    private func drawTrackNode(
        context: inout GraphicsContext,
        layout: MapPlotLayout,
        track: SetaTrack,
        displayPositions: [String: CGPoint],
        anchor: String?,
        neighbors: Set<String>,
        zoomHighlight: Bool
    ) {
        let point = layout.trackPoint(for: track, displayPositions: displayPositions)
        let isSelected = track.id == selectedTrackID || track.id == anchor
        let isPlaying = track.id == playingTrackID
        let isNeighbor = neighbors.contains(track.id)
        let isHovered = track.id == hoveredTrackID
        let isDraft = draftTrackIDs.contains(track.id)
        let isFinal = draftFinalIDs.contains(track.id)

        let radius: CGFloat
        if zoomHighlight {
            radius = TrackPresentation.zoomHoveredNodeRadius(for: track)
        } else {
            radius = TrackPresentation.nodeRadius(for: track, hovered: isHovered && showsLoupe)
        }
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
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(zoomHighlight ? SetaTheme.accent.opacity(0.35) : .black.opacity(0.12)),
            lineWidth: zoomHighlight ? 1 : 0.5
        )

        if isDraft {
            context.stroke(
                Path(ellipseIn: rect.insetBy(dx: -1.5, dy: -1.5)),
                with: .color(SetaTheme.draftGold.opacity(isFinal ? 0.9 : 0.45)),
                lineWidth: isFinal ? 1.5 : 1
            )
        }

        if zoomHighlight || isPlaying || isSelected {
            context.stroke(
                Path(ellipseIn: rect.insetBy(dx: -2.5, dy: -2.5)),
                with: .color(SetaTheme.accent),
                lineWidth: zoomHighlight ? 1.5 : (isPlaying ? 1.5 : 1.25)
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

private struct MapPickDisambiguationView: View {
    let candidates: [SetaTrack]
    let anchor: CGPoint
    let canvasSize: CGSize
    let trackOverrides: [String: TrackOverride]
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    private let menuWidth: CGFloat = 280
    private let rowHeight: CGFloat = 44
    private let maxVisibleRows = 8

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.001)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture(perform: onDismiss)

            let visible = Array(candidates.prefix(maxVisibleRows))
            let menuHeight = min(CGFloat(visible.count), CGFloat(maxVisibleRows)) * rowHeight + 36

            VStack(alignment: .leading, spacing: 0) {
                Text("\(candidates.count) tracks here")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SetaTheme.muted)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(visible) { track in
                            Button {
                                onSelect(track.id)
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: Camelot.colorHex(track.key)))
                                        .frame(width: 10, height: 10)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.displayTitle)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(SetaTheme.text)
                                            .lineLimit(1)
                                        Text(track.displayArtist)
                                            .font(.system(size: 10))
                                            .foregroundStyle(SetaTheme.muted)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    if let key = track.key {
                                        Text(key)
                                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(SetaTheme.muted)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .frame(height: rowHeight, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: rowHeight * CGFloat(maxVisibleRows))

                if candidates.count > maxVisibleRows {
                    Text("Showing nearest \(maxVisibleRows) — zoom in or narrow filters")
                        .font(.system(size: 9))
                        .foregroundStyle(SetaTheme.muted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
            .frame(width: menuWidth)
            .background(.white.opacity(0.98))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(SetaTheme.panelBorder)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 18, y: 6)
            .position(clampedMenuCenter(menuHeight: menuHeight))
        }
    }

    private func clampedMenuCenter(menuHeight: CGFloat) -> CGPoint {
        let margin: CGFloat = 12
        var x = anchor.x + 16
        var y = anchor.y - menuHeight / 2
        if x + menuWidth / 2 > canvasSize.width - margin {
            x = anchor.x - menuWidth - 16
        }
        x = min(max(x, menuWidth / 2 + margin), canvasSize.width - menuWidth / 2 - margin)
        y = min(max(y + menuHeight / 2, menuHeight / 2 + margin), canvasSize.height - menuHeight / 2 - margin)
        return CGPoint(x: x, y: y)
    }
}

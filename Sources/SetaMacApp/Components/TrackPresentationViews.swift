import SwiftUI
import SetaMacCore

struct TrackBadgesView: View {
    let badges: [TrackPresentation.Badge]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                Text(badge.text)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(foreground(for: badge))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(background(for: badge))
                    .overlay {
                        Capsule().strokeBorder(border(for: badge))
                    }
                    .clipShape(Capsule())
                    .help(badge.title ?? "")
            }
        }
    }

    private func foreground(for badge: TrackPresentation.Badge) -> Color {
        switch badge.kind {
        case .bpm, .energy, .key:
            return SetaTheme.text
        case .vocals:
            return Color(hex: "#7a3f95")
        case .instrumental:
            return SetaTheme.muted
        case .vocalsUnclear:
            return Color(hex: "#8a5a00")
        }
    }

    private func background(for badge: TrackPresentation.Badge) -> Color {
        if let backgroundHex = badge.backgroundHex {
            return Color(hex: String(backgroundHex.prefix(7)))
        }
        switch badge.kind {
        case .vocals:
            return Color(hex: "#7a3f95").opacity(0.12)
        case .instrumental:
            return Color.black.opacity(0.05)
        case .vocalsUnclear:
            return Color(hex: "#d48806").opacity(0.1)
        default:
            return SetaTheme.panel
        }
    }

    private func border(for badge: TrackPresentation.Badge) -> Color {
        if let borderHex = badge.borderHex {
            return Color(hex: String(borderHex.prefix(7))).opacity(0.5)
        }
        switch badge.kind {
        case .vocals:
            return Color(hex: "#7a3f95").opacity(0.24)
        case .instrumental:
            return Color.black.opacity(0.1)
        case .vocalsUnclear:
            return Color(hex: "#d48806").opacity(0.24)
        default:
            return SetaTheme.panelBorder
        }
    }
}

struct TrackTooltipView: View {
    let track: SetaTrack

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(track.displayTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SetaTheme.text)
                .lineLimit(2)
            Text(track.displayArtist)
                .font(.system(size: 11))
                .foregroundStyle(SetaTheme.muted)
                .padding(.bottom, 8)
            TrackBadgesView(badges: TrackPresentation.badges(for: track))
                .padding(.bottom, 8)
            if let warning = TrackPresentation.tooltipWarning(for: track) {
                Text(warning)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#9a6700"))
                    .padding(7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#d48806").opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.bottom, 8)
            }
            let meta = TrackPresentation.tooltipMetaParts(for: track)
            if !meta.isEmpty {
                Text(meta.joined(separator: " · "))
                    .font(.system(size: 10))
                    .foregroundStyle(SetaTheme.muted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 236, alignment: .leading)
        .background(.white.opacity(0.98))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(SetaTheme.panelBorder)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 16, y: 4)
    }
}

struct DraftEnergyRampView: View {
    let tracks: [SetaTrack]

    var body: some View {
        let geometry = EnergyRamp.geometry(tracks: tracks)
        GeometryReader { proxy in
            Canvas { context, size in
                guard !geometry.points.isEmpty else { return }
                let scaleX = size.width / 220
                let scaleY = size.height / 36
                var path = Path()
                for (index, point) in geometry.points.enumerated() {
                    let scaled = CGPoint(x: point.x * scaleX, y: point.y * scaleY)
                    if index == 0 { path.move(to: scaled) } else { path.addLine(to: scaled) }
                }
                context.stroke(path, with: .color(SetaTheme.accent), lineWidth: 1.5)
                for point in geometry.points {
                    let scaled = CGPoint(x: point.x * scaleX, y: point.y * scaleY)
                    context.fill(
                        Path(ellipseIn: CGRect(x: scaled.x - 2, y: scaled.y - 2, width: 4, height: 4)),
                        with: .color(SetaTheme.accent)
                    )
                }
            }
        }
        .frame(height: 36)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MapLoupeView: View {
    let track: SetaTrack
    let layout: MapPlotLayout
    let tracks: [SetaTrack]
    let neighborIDs: Set<String>
    let playingID: String?

    private let loupeSize: CGFloat = 140
    private let scale: CGFloat = 2.5

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            context.fill(Path(ellipseIn: CGRect(origin: .zero, size: size)), with: .color(.white))
            context.stroke(Path(ellipseIn: CGRect(origin: .zero, size: size)), with: .color(SetaTheme.panelBorder), lineWidth: 1)

            let anchor = layout.trackPoint(for: track, jitter: true)
            let sourceRadius: CGFloat = 56

            for item in tracks {
                let point = layout.trackPoint(for: item, jitter: true)
                let dx = point.x - anchor.x
                let dy = point.y - anchor.y
                guard hypot(dx, dy) <= sourceRadius else { continue }

                let mapped = CGPoint(
                    x: center.x + dx * scale,
                    y: center.y + dy * scale
                )
                let radius = TrackPresentation.nodeRadius(for: item, hovered: item.id == track.id)
                let rect = CGRect(x: mapped.x - radius, y: mapped.y - radius, width: radius * 2, height: radius * 2)
                var color = Color(hex: Camelot.colorHex(item.key))
                if neighborIDs.contains(item.id), item.id != track.id {
                    color = color.opacity(0.95)
                }
                context.fill(Path(ellipseIn: rect), with: .color(color))
                if item.id == playingID || item.id == track.id {
                    context.stroke(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(SetaTheme.accent), lineWidth: 1.5)
                }
            }
        }
        .frame(width: loupeSize, height: loupeSize)
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(SetaTheme.panelBorder) }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

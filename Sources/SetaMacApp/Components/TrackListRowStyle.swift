import SwiftUI
import SetaMacCore

struct TrackListRowAppearance {
    var isHighlighted: Bool = false
    var isInDraft: Bool = false
    var isQueueFocus: Bool = false
    var isHovered: Bool = false

    var background: Color {
        if isInDraft {
            return isHovered ? SetaTheme.draftGold.opacity(0.16) : SetaTheme.draftGold.opacity(0.1)
        }
        if isHighlighted {
            return isHovered ? Color(hex: "#6b4fd8").opacity(0.17) : SetaTheme.accentSoft
        }
        if isQueueFocus {
            return SetaTheme.accent.opacity(0.08)
        }
        return isHovered ? Color.white.opacity(0.92) : Color.white.opacity(0.55)
    }

    var border: Color {
        if isInDraft {
            return SetaTheme.draftGold.opacity(isHovered ? 0.48 : 0.38)
        }
        if isHighlighted {
            return SetaTheme.accent.opacity(isHovered ? 0.5 : 0.42)
        }
        if isHovered {
            return SetaTheme.accent.opacity(0.22)
        }
        return SetaTheme.panelBorder.opacity(0.9)
    }

    var showsAccentInset: Bool { isHighlighted }
    var showsQueueFocusRing: Bool { isQueueFocus && !isHighlighted }
}

struct TrackListRowChrome: View {
    let appearance: TrackListRowAppearance
    var cornerRadius: CGFloat = 8
    var insetWidth: CGFloat = 2

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(appearance.background)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(appearance.border, lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                if appearance.showsAccentInset {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(SetaTheme.accent)
                        .frame(width: insetWidth)
                        .padding(.vertical, 4)
                }
            }
            .overlay {
                if appearance.showsQueueFocusRing {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(SetaTheme.accent.opacity(0.2), lineWidth: 1)
                }
            }
    }
}

struct NeighborTrackMetaColumn: View {
    let track: SetaTrack
    var score: Double?
    var inDraft: Bool = false
    var anchor: Bool = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if !anchor {
                Group {
                    if let score {
                        Text("\(Int((score * 100).rounded()))%")
                            .font(.system(size: 8, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(SetaTheme.panel)
                            .clipShape(Capsule())
                    } else {
                        Color.clear.frame(height: 14)
                    }
                }
                .frame(minHeight: 14)
            }

            Group {
                if inDraft {
                    Text("draft")
                        .font(.system(size: 7, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color(hex: "#9a6b12"))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(SetaTheme.draftGold.opacity(0.16))
                        .clipShape(Capsule())
                } else {
                    Color.clear.frame(height: 14)
                }
            }
            .frame(minHeight: 14)

            HStack(spacing: 3) {
                Text(track.bpm.map { "\(Int($0.rounded()))" } ?? "?")
                    .font(.system(size: 8, weight: .semibold))
                Text(track.key ?? "?")
                    .font(.system(size: 8, weight: .semibold))
                    .padding(.horizontal, 4)
                    .background(Color(hex: Camelot.colorHex(track.key)).opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .frame(width: 46)
    }
}

struct DraftTrackMetaColumn: View {
    let track: SetaTrack

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(track.energy.map { String(format: "%.2f", $0) } ?? "?")
                .font(.system(size: 8, weight: .semibold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(SetaTheme.panel)
                .clipShape(Capsule())
                .frame(minHeight: 14)

            HStack(spacing: 3) {
                Text(track.bpm.map { "\(Int($0.rounded()))" } ?? "?")
                    .font(.system(size: 8, weight: .semibold))
                Text(track.key ?? "?")
                    .font(.system(size: 8, weight: .semibold))
                    .padding(.horizontal, 4)
                    .background(Color(hex: Camelot.colorHex(track.key)).opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .frame(width: 46)
    }
}

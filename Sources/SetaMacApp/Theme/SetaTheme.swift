import SwiftUI
import SetaMacCore

enum SetaTheme {
    static let background = Color(hex: "#ffffff")
    static let panel = Color(hex: "#f5f5f8")
    static let panelBorder = Color(hex: "#e2e2ea")
    static let text = Color(hex: "#1a1a24")
    static let muted = Color(hex: "#6b6b80")
    static let accent = Color(hex: "#6b4fd8")
    static let accentSoft = Color(hex: "#6b4fd8").opacity(0.12)
    static let draftGold = Color(hex: "#f5a623")

    static let minWindowWidth: CGFloat = 1280
    static let minWindowHeight: CGFloat = 760
    static let compactToolbarWidth: CGFloat = 1360
    static let filterBarHeight: CGFloat = 68
    static let playerHeight: CGFloat = 88
    static let legendHeaderChrome: CGFloat = 96
    static let mixDockWidth: CGFloat = 268
    static let legendWidth: CGFloat = 172
    static let uiRightInset: CGFloat = 214
    static let brandColumnWidth: CGFloat = 116
    static let searchFieldWidth: CGFloat = 280
    static let searchPopoverLeft: CGFloat = 10 + brandColumnWidth + 12

    static let bodyFont = Font.system(size: 14, weight: .regular, design: .default)
}

struct GlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = 14
    var compact: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(compact ? EdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8) : EdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8))
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.75))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(SetaTheme.panelBorder.opacity(0.75))
                    }
                    .shadow(color: .black.opacity(compact ? 0.06 : 0.08), radius: compact ? 12 : 24, y: compact ? 2 : 4)
            }
    }
}

struct SetaKbd: View {
    let text: String
    var active: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(SetaTheme.text)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(.white.opacity(0.9))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(active ? SetaTheme.accent.opacity(0.35) : SetaTheme.panelBorder)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct MixDockTabButton: View {
    let shortcut: String
    let title: String
    var count: Int = 0
    var isActive: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                SetaKbd(text: shortcut, active: isActive)
                Text(title)
                    .font(.system(size: 10, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? SetaTheme.text : SetaTheme.muted)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SetaTheme.muted)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct SetaChip: View {
    let title: String
    var isActive: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isActive ? SetaTheme.accent : (isDisabled ? SetaTheme.muted : SetaTheme.muted))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isActive ? SetaTheme.accentSoft : SetaTheme.panel)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isActive ? SetaTheme.accent.opacity(0.32) : SetaTheme.panelBorder,
                            lineWidth: 1
                        )
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }
}

struct SetaIconChip: View {
    let systemImage: String
    let help: String
    var isActive: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? SetaTheme.accent : SetaTheme.muted)
                .frame(width: 28, height: 28)
                .background(isActive ? SetaTheme.accentSoft : SetaTheme.panel)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isActive ? SetaTheme.accent.opacity(0.32) : SetaTheme.panelBorder,
                            lineWidth: 1
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .help(help)
    }
}

struct SetaSecondaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SetaTheme.text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(SetaTheme.panel)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(SetaTheme.panelBorder)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SetaResetButton: View {
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("↺")
                .font(.system(size: 12))
                .foregroundStyle(SetaTheme.accent)
                .frame(width: 22, height: 22)
                .background(disabled ? Color.clear : SetaTheme.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }
}

struct FloatingChrome<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(.white.opacity(0.75))
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(SetaTheme.panelBorder.opacity(0.75))
                    .frame(height: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 0, y: 1)
    }
}

extension Color {
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(raw, radix: 16) ?? 0x555770
        let red = Double((value >> 16) & 0xff) / 255
        let green = Double((value >> 8) & 0xff) / 255
        let blue = Double(value & 0xff) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

func formatPlaybackTime(_ seconds: Double) -> String {
    TrackPresentation.formatPlaybackTime(seconds)
}

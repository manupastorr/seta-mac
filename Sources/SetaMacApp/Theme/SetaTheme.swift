import AppKit
import SwiftUI
import SetaMacCore

enum SetaTheme {
    static let background = Color(light: "#ffffff", dark: "#111116")
    static let panel = Color(light: "#f5f5f8", dark: "#202029")
    static let panelElevated = Color(light: "#ffffff", dark: "#2a2a35")
    static let panelBorder = Color(light: "#e2e2ea", dark: "#3a3a48")
    static let text = Color(light: "#1a1a24", dark: "#f4f4f7")
    static let muted = Color(light: "#6b6b80", dark: "#aaaabd")
    static let accent = Color(hex: "#6b4fd8")
    static let accentSoft = Color(hex: "#6b4fd8").opacity(0.12)
    static let draftGold = Color(hex: "#f5a623")
    static let neutralOverlay = Color(light: "#ffffff", dark: "#252530")
    static let shadow = Color.black

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
                    .fill(SetaTheme.neutralOverlay.opacity(0.75))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(SetaTheme.panelBorder.opacity(0.75))
                    }
                    .shadow(color: SetaTheme.shadow.opacity(compact ? 0.06 : 0.16), radius: compact ? 12 : 24, y: compact ? 2 : 4)
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
            .background(SetaTheme.panelElevated.opacity(0.9))
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
    var expand: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SetaTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: expand ? .infinity : nil)
                .fixedSize(horizontal: !expand, vertical: false)
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
            .background(SetaTheme.neutralOverlay.opacity(0.75))
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(SetaTheme.panelBorder.opacity(0.75))
                    .frame(height: 1)
            }
            .shadow(color: SetaTheme.shadow.opacity(0.08), radius: 0, y: 1)
    }
}

struct SetaSheetLayout<Content: View, Footer: View>: View {
    let title: String
    var subtitle: String?
    var width: CGFloat = 540
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(SetaTheme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(SetaTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider().opacity(0.65)

            content()
                .padding(18)

            Divider().opacity(0.65)

            footer()
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        }
        .frame(width: width)
        .fixedSize(horizontal: false, vertical: true)
        .background(SetaTheme.background)
    }
}

struct SetaSheetSectionCard<Content: View>: View {
    let icon: String
    let title: String
    var subtitle: String?
    var compact: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SetaTheme.accent)
                    .frame(width: compact ? 24 : 28, height: compact ? 24 : 28)
                    .background(SetaTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SetaTheme.text)
                    if let subtitle, !compact {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(SetaTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .help(subtitle ?? "")

            content()
        }
        .padding(compact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SetaTheme.panel)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(SetaTheme.panelBorder.opacity(0.9))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

extension Color {
    init(light: String, dark: String) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            return NSColor(hex: bestMatch == .darkAqua ? dark : light)
        })
    }

    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let rgbRaw: String
        let alpha: Double
        if raw.count == 8 {
            rgbRaw = String(raw.prefix(6))
            alpha = Double(UInt8(String(raw.suffix(2)), radix: 16) ?? 255) / 255
        } else {
            rgbRaw = raw
            alpha = 1
        }
        let value = UInt64(rgbRaw, radix: 16) ?? 0x555770
        let red = Double((value >> 16) & 0xff) / 255
        let green = Double((value >> 8) & 0xff) / 255
        let blue = Double(value & 0xff) / 255
        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let rgbRaw: String
        let alpha: Double
        if raw.count == 8 {
            rgbRaw = String(raw.prefix(6))
            alpha = Double(UInt8(String(raw.suffix(2)), radix: 16) ?? 255) / 255
        } else {
            rgbRaw = raw
            alpha = 1
        }
        let value = UInt64(rgbRaw, radix: 16) ?? 0x555770
        let red = CGFloat((value >> 16) & 0xff) / 255
        let green = CGFloat((value >> 8) & 0xff) / 255
        let blue = CGFloat(value & 0xff) / 255
        self.init(red: red, green: green, blue: blue, alpha: CGFloat(alpha))
    }
}

func formatPlaybackTime(_ seconds: Double) -> String {
    TrackPresentation.formatPlaybackTime(seconds)
}

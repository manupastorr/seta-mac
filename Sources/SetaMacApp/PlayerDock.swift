import SwiftUI
import SetaMacCore

struct PlayerDock: View {
    @ObservedObject var store: LibraryStore
    @ObservedObject private var player: AudioPlayerController

    init(store: LibraryStore) {
        self.store = store
        self.player = store.player
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(SetaTheme.panelBorder.opacity(0.75))
                .frame(height: 1)
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    transportButton("◀") { store.playRelative(step: -1) }
                        .disabled(store.playQueue.count <= 1)
                    transportButton(player.isPlaying ? "❚❚" : "▶", main: true) {
                        store.togglePlayPause()
                    }
                    transportButton("▶|") { store.playRelative(step: 1) }
                        .disabled(store.playQueue.count <= 1)
                    transportButton("+") { store.addSelectedToDraft() }
                        .help("Add to draft (a)")
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SetaTheme.text)
                        .lineLimit(1)
                    Text(displayArtist)
                        .font(.system(size: 12))
                        .foregroundStyle(SetaTheme.muted)
                        .lineLimit(1)
                    if let track = currentTrack {
                        TrackBadgesView(track: track, override: store.trackOverride(for: track.id))
                            .padding(.top, 2)
                    }
                }
                .frame(minWidth: 140, maxWidth: 260, alignment: .leading)
                .layoutPriority(1)

                VStack(spacing: 4) {
                    WaveformView(
                        track: player.currentTrack,
                        progress: player.progress,
                        onSeek: { store.seekToProgress($0) }
                    )
                    .frame(height: 40)
                    HStack(spacing: 8) {
                        Text(formatPlaybackTime(player.currentTime))
                            .fixedSize()
                        Spacer(minLength: 8)
                        Text(formatPlaybackTime(player.duration))
                            .fixedSize()
                        Spacer(minLength: 8)
                        PlayerShortcutHints()
                            .layoutPriority(-1)
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SetaTheme.muted)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.75))
            .background(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.06), radius: 24, y: -6)
        }
    }

    private var currentTrack: SetaTrack? {
        player.currentTrack
    }

    private var displayTitle: String {
        currentTrack?.displayTitle ?? "Nothing playing"
    }

    private var displayArtist: String {
        if currentTrack != nil {
            return currentTrack?.displayArtist ?? ""
        }
        return "Click a node on the map to preview"
    }

    private func transportButton(_ title: String, main: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: main ? 16 : 13, weight: .semibold))
                .frame(width: main ? 44 : 36, height: main ? 44 : 36)
                .background(main ? SetaTheme.accent : SetaTheme.panel)
                .foregroundStyle(main ? .white : SetaTheme.text)
                .clipShape(Circle())
                .shadow(color: main ? SetaTheme.accent.opacity(0.28) : .clear, radius: 5, y: 2)
                .overlay {
                    Circle().strokeBorder(SetaTheme.panelBorder, lineWidth: main ? 0 : 1)
                }
        }
        .buttonStyle(.plain)
    }
}

struct WaveformView: View {
    let track: SetaTrack?
    let progress: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                drawWaveform(context: &context, size: size)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = min(1, max(0, value.location.x / max(proxy.size.width, 1)))
                        onSeek(ratio)
                    }
            )
        }
        .background(track == nil ? Color.black.opacity(0.04) : SetaTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).strokeBorder(SetaTheme.panelBorder.opacity(0.8))
        }
        .opacity(track == nil ? 0.45 : 1)
    }

    private func drawWaveform(context: inout GraphicsContext, size: CGSize) {
        guard
            let peaks = track?.waveformPeak,
            let lows = track?.waveformLow,
            let mids = track?.waveformMid,
            let highs = track?.waveformHigh,
            !peaks.isEmpty,
            peaks.count == lows.count,
            peaks.count == mids.count,
            peaks.count == highs.count
        else {
            drawPlaceholder(context: &context, size: size)
            return
        }

        let barCount = peaks.count
        let step = size.width / CGFloat(barCount)
        let barWidth = max(1, step * 0.72)
        let midY = size.height / 2
        let playedX = size.width * progress

        for index in 0..<barCount {
            let x = CGFloat(index) * step
            let amp = CGFloat(peaks[index]) * (size.height * 0.46)
            let rect = CGRect(x: x, y: midY - amp, width: barWidth, height: amp * 2)
            let bandColor = bandColor(low: lows[index], mid: mids[index], high: highs[index])
            let color = x <= playedX ? bandColor : bandColor.opacity(0.35)
            context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
        }

        var playhead = Path()
        playhead.move(to: CGPoint(x: playedX, y: 0))
        playhead.addLine(to: CGPoint(x: playedX, y: size.height))
        context.stroke(playhead, with: .color(SetaTheme.accent.opacity(0.7)), lineWidth: 1)
    }

    private func drawPlaceholder(context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        let midY = size.height / 2
        let step = size.width / 80
        for index in 0..<80 {
            let x = CGFloat(index) * step
            let amp = CGFloat((index % 7) + 2)
            path.move(to: CGPoint(x: x, y: midY - amp))
            path.addLine(to: CGPoint(x: x, y: midY + amp))
        }
        context.stroke(path, with: .color(SetaTheme.muted.opacity(0.25)), lineWidth: 1)
    }

    private func bandColor(low: Double, mid: Double, high: Double) -> Color {
        let total = max(low + mid + high, 0.0001)
        let mix = low / total * 0.2 + mid / total * 0.55 + high / total * 0.95
        return SetaTheme.accent.opacity(0.35 + mix * 0.55)
    }
}

private struct PlayerShortcutHints: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                SetaKbd(text: "?")
                Text("shortcuts ·")
                SetaKbd(text: "/")
                Text("search ·")
                SetaKbd(text: "a")
                Text("add ·")
                SetaKbd(text: "d")
                Text("draft")
            }
            HStack(spacing: 4) {
                SetaKbd(text: "?")
                Text("·")
                SetaKbd(text: "/")
                Text("·")
                SetaKbd(text: "a")
                Text("·")
                SetaKbd(text: "d")
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(SetaTheme.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
}

struct ShortcutsHelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let rows: [(keys: String, desc: String)] = [
        ("Space", "Play / pause"),
        ("← →", "Previous / next track"),
        ("Shift ← →", "Seek ±10 seconds"),
        ("n", "Toggle neighbor queue"),
        ("a", "Add selected track to draft"),
        ("d", "Open draft panel"),
        ("m", "Open neighbors panel"),
        ("k / z", "Toggle keys / zones legends"),
        ("r", "Reset map zoom"),
        ("?", "Show this help")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard shortcuts")
                .font(.title3.bold())
            ForEach(rows, id: \.keys) { row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.keys)
                        .font(.caption.monospaced())
                        .frame(width: 88, alignment: .leading)
                    Text(row.desc)
                        .font(.body)
                }
            }
            HStack {
                Spacer()
                Button("Close") { dismiss() }
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

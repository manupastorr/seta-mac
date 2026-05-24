import CoreGraphics
import Foundation

public enum TrackPresentation {
    public static let lowBPMConfidence = 0.45
    public static let vocalsShowConfidence = 0.55
    public static let hoverRadiusBoost: CGFloat = 5

    public static func nodeRadius(for track: SetaTrack, hovered: Bool = false) -> CGFloat {
        let base = 3 + CGFloat((track.durationSec.map { min($0 / 180, 1) } ?? 0))
        return hovered ? base + hoverRadiusBoost : base
    }

    public struct Badge: Equatable, Sendable {
        public enum Kind: String, Sendable {
            case bpm
            case key
            case energy
            case vocals
            case instrumental
            case vocalsUnclear
        }

        public let kind: Kind
        public let text: String
        public let borderHex: String?
        public let backgroundHex: String?
        public let title: String?

        public init(kind: Kind, text: String, borderHex: String? = nil, backgroundHex: String? = nil, title: String? = nil) {
            self.kind = kind
            self.text = text
            self.borderHex = borderHex
            self.backgroundHex = backgroundHex
            self.title = title
        }
    }

    public static func badges(for track: SetaTrack) -> [Badge] {
        var items: [Badge] = []
        let bpmText = track.bpm.map { "\(Int($0.rounded())) BPM" } ?? "? BPM"
        items.append(Badge(kind: .bpm, text: bpmText))

        let keyText = track.key ?? "?"
        let keyColor = Camelot.colorHex(track.key)
        items.append(
            Badge(
                kind: .key,
                text: keyText,
                borderHex: keyColor + "44",
                backgroundHex: keyColor + "1a"
            )
        )

        let energy = track.energy ?? 0.5
        items.append(
            Badge(
                kind: .energy,
                text: "Int \(String(format: "%.2f", energy))",
                title: "Estimated intensity (0–1, map Y uses library range)"
            )
        )

        if let vocalsBadge = vocalsBadge(for: track) {
            items.append(vocalsBadge)
        }
        return items
    }

    public static func vocalsBadge(for track: SetaTrack) -> Badge? {
        guard let label = track.vocals,
              let confidence = track.vocalsConfidence,
              confidence >= vocalsShowConfidence else { return nil }

        switch label {
        case "yes":
            return Badge(
                kind: .vocals,
                text: "Vocals",
                title: "Likely vocals (\(String(format: "%.2f", confidence)) confidence)"
            )
        case "no":
            return Badge(
                kind: .instrumental,
                text: "Inst",
                title: "Likely instrumental (\(String(format: "%.2f", confidence)) confidence)"
            )
        case "unclear":
            return Badge(
                kind: .vocalsUnclear,
                text: "Voc ?",
                title: "Vocal presence unclear (\(String(format: "%.2f", confidence)) confidence)"
            )
        default:
            return nil
        }
    }

    public static func tooltipWarning(for track: SetaTrack) -> String? {
        if track.bpmOctaveCorrected == true,
           let raw = track.bpmRaw,
           let bpm = track.bpm,
           abs(bpm - raw) >= 4 {
            if track.bpmSource == "tag" {
                return "Half-time tag (\(Int(raw.rounded()))→\(Int(bpm.rounded())) BPM)"
            }
            return "Octave corrected (\(Int(raw.rounded()))→\(Int(bpm.rounded())) BPM)"
        }
        if let confidence = track.bpmConfidence, confidence < lowBPMConfidence {
            return "Low BPM confidence (\(String(format: "%.2f", confidence))) — verify in Rekordbox"
        }
        return nil
    }

    public static func tooltipMetaParts(for track: SetaTrack) -> [String] {
        var parts: [String] = []
        if let genre = track.genre, !genre.isEmpty { parts.append(genre) }
        if let batch = track.batch, !batch.isEmpty { parts.append(batch) }
        if let duration = track.durationSec {
            parts.append(formatDuration(duration))
        }
        return parts
    }

    public static func formatDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let remainder = total % 60
        return "\(minutes):\(String(format: "%02d", remainder))"
    }

    public static func formatPlaybackTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        return formatDuration(seconds)
    }
}

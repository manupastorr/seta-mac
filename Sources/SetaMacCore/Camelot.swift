import Foundation

public enum Camelot {
    public static let colors: [String: String] = [
        "1A": "#C62828", "1B": "#EF5350",
        "2A": "#E65100", "2B": "#FF9800",
        "3A": "#F57F17", "3B": "#FFCA28",
        "4A": "#9E9D24", "4B": "#CDDC39",
        "5A": "#558B2F", "5B": "#8BC34A",
        "6A": "#2E7D32", "6B": "#66BB6A",
        "7A": "#00695C", "7B": "#26A69A",
        "8A": "#00838F", "8B": "#4DD0E1",
        "9A": "#1565C0", "9B": "#42A5F5",
        "10A": "#4527A0", "10B": "#7E57C2",
        "11A": "#6A1B9A", "11B": "#AB47BC",
        "12A": "#AD1457", "12B": "#EC407A"
    ]

    public static let unknownColor = "#555770"

    public static func colorHex(_ code: String?) -> String {
        guard let code else { return unknownColor }
        return colors[code.uppercased()] ?? unknownColor
    }

    public static func compatible(_ a: String?, _ b: String?) -> Double {
        guard let a = a?.uppercased(), let b = b?.uppercased(), !a.isEmpty, !b.isEmpty else {
            return 0
        }
        if a == b { return 1 }

        let aNumberText = String(a.dropLast())
        let bNumberText = String(b.dropLast())
        guard let aLetter = a.last, let bLetter = b.last else { return 0 }

        if aNumberText == bNumberText && aLetter != bLetter {
            return 0.82
        }

        guard let aNumber = Int(aNumberText), let bNumber = Int(bNumberText) else {
            return 0
        }

        let rawDiff = abs(aNumber - bNumber)
        let diff = min(rawDiff, 12 - rawDiff)
        if aLetter == bLetter && diff == 1 {
            return 0.72
        }
        if diff == 1 {
            return 0.55
        }
        return 0
    }

    public static func bpmCompatible(_ a: Double?, _ b: Double?) -> Double {
        guard let a, let b else { return 0.35 }
        let diff = abs(a - b)
        if diff <= 1 { return 1 }
        if diff <= 2 { return 0.9 }
        if diff <= 4 { return 0.7 }
        if diff <= 6 { return 0.45 }
        return 0
    }

    public static func mixScore(keyA: String?, keyB: String?, bpmA: Double?, bpmB: Double?) -> Double {
        let harmonic = compatible(keyA, keyB)
        if harmonic <= 0 { return 0 }
        return harmonic * bpmCompatible(bpmA, bpmB)
    }
}


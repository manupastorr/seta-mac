import Foundation

public struct ScanProgress: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case starting
        case scanning
        case writing
        case finished
    }

    public var phase: Phase
    public var total: Int?
    public var completed: Int?

    public init(phase: Phase = .starting, total: Int? = nil, completed: Int? = nil) {
        self.phase = phase
        self.total = total
        self.completed = completed
    }
}

public enum ScanProgressParser {
    public static func ingest(line: String, into progress: inout ScanProgress) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if trimmed.hasPrefix("Found ") {
            if let total = parseCount(from: trimmed, prefix: "Found ", suffix: " audio files") {
                progress.phase = .scanning
                progress.total = total
                if progress.completed == nil {
                    progress.completed = 0
                }
            }
            return
        }

        if trimmed.hasPrefix("cached ") || trimmed.hasPrefix("analyzed ") {
            if let counts = parseProgressCounts(trimmed) {
                progress.phase = .scanning
                progress.total = counts.total
                progress.completed = counts.completed
            }
            return
        }

        if trimmed.hasPrefix("Wrote ") {
            progress.phase = .finished
            if let total = progress.total {
                progress.completed = total
            }
        }
    }

    public static func statusMessage(
        for progress: ScanProgress,
        startedAt: Date,
        now: Date = Date()
    ) -> String {
        switch progress.phase {
        case .starting:
            return "Preparing scan…"
        case .writing:
            return "Writing library…"
        case .finished:
            return "Finishing scan…"
        case .scanning:
            guard let total = progress.total, total > 0 else {
                return "Scanning…"
            }

            let completed = min(progress.completed ?? 0, total)
            if completed <= 0 {
                return "Scanning \(total) tracks…"
            }

            let elapsed = max(now.timeIntervalSince(startedAt), 0.1)
            let remainingCount = max(total - completed, 0)
            if remainingCount == 0 {
                return "Scanning \(completed)/\(total) · finishing…"
            }

            let rate = Double(completed) / elapsed
            if rate <= 0 {
                return "Scanning \(completed)/\(total)…"
            }

            let etaSeconds = Double(remainingCount) / rate
            return "Scanning \(completed)/\(total) · \(formatETA(seconds: etaSeconds))"
        }
    }

    public static func formatETA(seconds: TimeInterval) -> String {
        let rounded = max(Int(seconds.rounded()), 1)
        if rounded < 60 {
            return rounded == 1 ? "~1 sec left" : "~\(rounded) sec left"
        }

        let minutes = Int((Double(rounded) / 60.0).rounded())
        return minutes == 1 ? "~1 min left" : "~\(minutes) min left"
    }

    private static func parseCount(from line: String, prefix: String, suffix: String) -> Int? {
        guard line.hasPrefix(prefix), line.hasSuffix(suffix) else { return nil }
        let number = line.dropFirst(prefix.count).dropLast(suffix.count)
        return Int(number)
    }

    private static func parseProgressCounts(_ line: String) -> (completed: Int, total: Int)? {
        guard let slash = line.lastIndex(of: "/") else { return nil }
        let totalPart = line[line.index(after: slash)...]
        guard let total = Int(totalPart) else { return nil }

        let beforeSlash = line[..<slash]
        guard let space = beforeSlash.lastIndex(of: " ") else { return nil }
        let completedPart = beforeSlash[beforeSlash.index(after: space)...]
        guard let completed = Int(completedPart) else { return nil }

        return (completed, total)
    }
}

public final class ScanProgressTracker: @unchecked Sendable {
    private var progress = ScanProgress()
    private let startedAt: Date
    private let lock = NSLock()
    private let onUpdate: @Sendable (String) -> Void

    public init(startedAt: Date = Date(), onUpdate: @escaping @Sendable (String) -> Void) {
        self.startedAt = startedAt
        self.onUpdate = onUpdate
    }

    public func handleLine(_ line: String) {
        lock.lock()
        ScanProgressParser.ingest(line: line, into: &progress)
        let message = ScanProgressParser.statusMessage(for: progress, startedAt: startedAt)
        lock.unlock()
        onUpdate(message)
    }
}

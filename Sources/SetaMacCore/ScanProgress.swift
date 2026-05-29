import Foundation

public struct ScanProgress: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case starting
        case scanning
        case writing
        case finished
    }

    public enum ScanStep: Equatable, Sendable {
        case cache
        case analyze
    }

    public var phase: Phase
    public var total: Int?
    public var completed: Int?
    public var step: ScanStep?
    public var checkpointCompleted: Int?
    public var checkpointAt: Date?

    public init(
        phase: Phase = .starting,
        total: Int? = nil,
        completed: Int? = nil,
        step: ScanStep? = nil,
        checkpointCompleted: Int? = nil,
        checkpointAt: Date? = nil
    ) {
        self.phase = phase
        self.total = total
        self.completed = completed
        self.step = step
        self.checkpointCompleted = checkpointCompleted
        self.checkpointAt = checkpointAt
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
                progress.completed = 0
                progress.step = nil
                progress.checkpointCompleted = nil
                progress.checkpointAt = nil
            }
            return
        }

        if trimmed.hasPrefix("cached ") {
            if let counts = parseProgressCounts(trimmed) {
                progress.phase = .scanning
                progress.step = .cache
                progress.total = counts.total
                progress.completed = counts.completed
            }
            return
        }

        if trimmed.hasPrefix("analyzed ") {
            if let counts = parseProgressCounts(trimmed) {
                progress.phase = .scanning
                progress.step = .analyze
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

    public static func finalizeCheckpoint(into progress: inout ScanProgress, now: Date = Date()) {
        guard progress.step == .analyze, let completed = progress.completed else { return }
        progress.checkpointCompleted = completed
        progress.checkpointAt = now
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

            switch progress.step {
            case .cache:
                if completed >= total {
                    return "Reading cache… \(completed)/\(total) · finishing…"
                }
                return "Reading cache… \(completed)/\(total) · analyzing new tracks next…"

            case .analyze:
                let remainingCount = max(total - completed, 0)
                if remainingCount == 0 {
                    return "Analyzing \(completed)/\(total) · finishing…"
                }

                if let checkpointCompleted = progress.checkpointCompleted,
                   let checkpointAt = progress.checkpointAt,
                   completed > checkpointCompleted,
                   let rate = recentRate(
                       completed: completed,
                       lastCompleted: checkpointCompleted,
                       lastProgressAt: checkpointAt,
                       now: now
                   ) {
                    let etaSeconds = Double(remainingCount) / rate
                    return "Analyzing \(completed)/\(total) · \(formatETA(seconds: etaSeconds))"
                }

                return "Analyzing \(completed)/\(total)…"

            case nil:
                return "Scanning \(completed)/\(total)…"
            }
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

    private static func recentRate(
        completed: Int,
        lastCompleted: Int,
        lastProgressAt: Date,
        now: Date
    ) -> Double? {
        let deltaCount = completed - lastCompleted
        guard deltaCount > 0 else { return nil }
        let deltaTime = now.timeIntervalSince(lastProgressAt)
        guard deltaTime > 0 else { return nil }
        return Double(deltaCount) / deltaTime
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
        ScanProgressParser.finalizeCheckpoint(into: &progress)
        lock.unlock()
        onUpdate(message)
    }
}

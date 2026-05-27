import Foundation

public enum TransitionKind: String, Codable, Equatable, Sendable {
    case smooth
    case lift
    case bridge
    case contrast
    case closing
    case risky
}

public enum JourneyMode: String, Codable, CaseIterable, Equatable, Sendable {
    case journeyCoach
    case smooth
    case lift
    case bridge
    case contrast
    case closing
}

public struct JourneyIntent: Codable, Equatable, Sendable {
    public var mode: JourneyMode
    public var targetMomentID: String?
    public var targetBPMRange: ClosedRange<Double>?
    public var targetTrackID: String?

    public init(
        mode: JourneyMode = .journeyCoach,
        targetMomentID: String? = nil,
        targetBPMRange: ClosedRange<Double>? = nil,
        targetTrackID: String? = nil
    ) {
        self.mode = mode
        self.targetMomentID = targetMomentID
        self.targetBPMRange = targetBPMRange
        self.targetTrackID = targetTrackID
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case targetMomentID
        case targetBPMMin
        case targetBPMMax
        case targetTrackID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decodeIfPresent(JourneyMode.self, forKey: .mode) ?? .journeyCoach
        targetMomentID = try container.decodeIfPresent(String.self, forKey: .targetMomentID)
        targetTrackID = try container.decodeIfPresent(String.self, forKey: .targetTrackID)
        if let min = try container.decodeIfPresent(Double.self, forKey: .targetBPMMin),
           let max = try container.decodeIfPresent(Double.self, forKey: .targetBPMMax) {
            targetBPMRange = min ... max
        } else {
            targetBPMRange = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(targetMomentID, forKey: .targetMomentID)
        try container.encodeIfPresent(targetTrackID, forKey: .targetTrackID)
        try container.encodeIfPresent(targetBPMRange?.lowerBound, forKey: .targetBPMMin)
        try container.encodeIfPresent(targetBPMRange?.upperBound, forKey: .targetBPMMax)
    }
}

public struct TransitionComponent: Codable, Equatable, Sendable {
    public let name: String
    public let score: Double
    public let weight: Double

    public init(name: String, score: Double, weight: Double) {
        self.name = name
        self.score = score
        self.weight = weight
    }
}

public struct TransitionScore: Codable, Equatable, Sendable {
    public let total: Double
    public let confidence: Double
    public let kind: TransitionKind
    public let components: [TransitionComponent]
    public let reasons: [String]
    public let warnings: [String]

    public init(
        total: Double,
        confidence: Double,
        kind: TransitionKind,
        components: [TransitionComponent],
        reasons: [String],
        warnings: [String]
    ) {
        self.total = total
        self.confidence = confidence
        self.kind = kind
        self.components = components
        self.reasons = reasons
        self.warnings = warnings
    }

    public var isWeak: Bool { total < SmartMixEngine.weakLinkThreshold }
}

public struct TransitionFeedback: Codable, Equatable, Identifiable, Sendable {
    public var id: String { Self.key(from: fromTrackID, to: toTrackID) }
    public let fromTrackID: String
    public let toTrackID: String
    public var rating: Int
    public var note: String?
    public var updatedAt: TimeInterval

    public init(
        fromTrackID: String,
        toTrackID: String,
        rating: Int,
        note: String? = nil,
        updatedAt: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.fromTrackID = fromTrackID
        self.toTrackID = toTrackID
        self.rating = max(-2, min(2, rating))
        self.note = note
        self.updatedAt = updatedAt
    }

    public static func key(from: String, to: String) -> String {
        "\(from)\u{1f}\(to)"
    }
}

public struct SmartNeighbor: Equatable, Identifiable, Sendable {
    public var id: String { track.id }
    public let track: SetaTrack
    public let score: TransitionScore
}

public struct SmartBridgeRoute: Equatable, Identifiable, Sendable {
    public let id: String
    public let tracks: [SetaTrack]
    public let transitions: [TransitionScore]
    public let totalCost: Double

    public init(tracks: [SetaTrack], transitions: [TransitionScore], totalCost: Double) {
        id = tracks.map(\.id).joined(separator: ">")
        self.tracks = tracks
        self.transitions = transitions
        self.totalCost = totalCost
    }
}

public enum DraftSuggestionKind: String, Codable, Equatable, Sendable {
    case insertBridge
    case replaceNext
    case reorderLocalSection
}

public struct DraftSuggestion: Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: DraftSuggestionKind
    public let title: String
    public let trackIDs: [String]
    public let route: SmartBridgeRoute?
}

public struct DraftWeakLink: Equatable, Identifiable, Sendable {
    public let id: String
    public let from: SetaTrack
    public let to: SetaTrack
    public let score: TransitionScore
    public let suggestions: [DraftSuggestion]
}

public enum SmartMixEngine {
    public static let weakLinkThreshold = 0.58
    public static let defaultNeighborLimit = 40
    public static let bridgePoolLimit = 300
    public static let bridgeRouteLimit = 5

    public static func score(
        from source: SetaTrack,
        to target: SetaTrack,
        intent: JourneyIntent = JourneyIntent(),
        feedback: [String: TransitionFeedback] = [:]
    ) -> TransitionScore {
        var reasons: [String] = []
        var warnings: [String] = []
        var components: [TransitionComponent] = []
        var confidenceParts: [Double] = []

        let harmonic = Camelot.compatible(source.key, target.key)
        if harmonic >= 1 {
            reasons.append("same key")
        } else if harmonic >= 0.8 {
            reasons.append("relative key")
        } else if harmonic >= 0.55 {
            reasons.append("near key")
        } else {
            warnings.append("key clash")
        }
        if source.key == nil || target.key == nil {
            warnings.append("missing key")
            confidenceParts.append(0.25)
        } else {
            confidenceParts.append(1)
        }
        components.append(TransitionComponent(name: "key", score: harmonic, weight: 0.30))

        let bpmScore = bpmScore(source.bpm, target.bpm, reasons: &reasons, warnings: &warnings)
        components.append(TransitionComponent(name: "bpm", score: bpmScore, weight: 0.20))
        confidenceParts.append(source.bpm == nil || target.bpm == nil ? 0.25 : 1)

        let energyScore = energyDirectionScore(from: source, to: target, mode: intent.mode, reasons: &reasons, warnings: &warnings)
        components.append(TransitionComponent(name: "energy", score: energyScore, weight: 0.18))
        components.append(TransitionComponent(name: "phrase", score: phraseEnergyFit(from: source, to: target, reasons: &reasons), weight: 0.12))
        components.append(TransitionComponent(name: "zone", score: zoneScore(from: source, to: target, intent: intent, reasons: &reasons), weight: 0.08))
        components.append(TransitionComponent(name: "source", score: genreSourceScore(from: source, to: target, reasons: &reasons), weight: 0.05))

        let feedbackScore = feedbackComponent(from: source, to: target, feedback: feedback, reasons: &reasons, warnings: &warnings)
        components.append(TransitionComponent(name: "feedback", score: feedbackScore, weight: 0.07))

        var totalWeight = 0.0
        var weighted = 0.0
        for component in components {
            totalWeight += component.weight
            weighted += component.score * component.weight
        }
        var total = totalWeight > 0 ? weighted / totalWeight : 0

        if hasVocalClash(source, target) {
            warnings.append("vocal risk")
            total -= 0.12
        }
        if source.bpm == nil || target.bpm == nil || source.key == nil || target.key == nil {
            total = min(total, 0.50)
        }
        total = clamp(total)

        let confidence = clamp(confidenceParts.reduce(0, +) / Double(max(confidenceParts.count, 1)))
        return TransitionScore(
            total: total,
            confidence: confidence,
            kind: classifyKind(total: total, source: source, target: target, intent: intent, warnings: warnings),
            components: components,
            reasons: compact(reasons, limit: 4),
            warnings: compact(warnings, limit: 3)
        )
    }

    public static func neighbors(
        for trackID: String,
        in tracks: [SetaTrack],
        intent: JourneyIntent = JourneyIntent(),
        feedback: [String: TransitionFeedback] = [:],
        limit: Int = defaultNeighborLimit,
        includeLowConfidence: Bool = false
    ) -> [SmartNeighbor] {
        guard let source = tracks.first(where: { $0.id == trackID }) else { return [] }
        return tracks
            .filter { $0.id != trackID }
            .compactMap { target -> SmartNeighbor? in
                let score = score(from: source, to: target, intent: intent, feedback: feedback)
                if !includeLowConfidence, score.confidence < 0.5 { return nil }
                guard score.total >= 0.42 || includeLowConfidence else { return nil }
                return SmartNeighbor(track: target, score: score)
            }
            .sorted { lhs, rhs in
                if lhs.score.total != rhs.score.total { return lhs.score.total > rhs.score.total }
                return lhs.track.displayTitle < rhs.track.displayTitle
            }
            .prefix(limit)
            .map { $0 }
    }

    public static func bridgeRoutes(
        from sourceID: String,
        to targetID: String? = nil,
        in tracks: [SetaTrack],
        intent: JourneyIntent = JourneyIntent(mode: .bridge),
        feedback: [String: TransitionFeedback] = [:],
        limit: Int = bridgeRouteLimit
    ) -> [SmartBridgeRoute] {
        guard let source = tracks.first(where: { $0.id == sourceID }) else { return [] }
        let pool = Array(tracks.filter { $0.id != sourceID }.prefix(bridgePoolLimit))
        let targets = bridgeTargets(targetID: targetID, pool: pool, intent: intent)
        guard !targets.isEmpty else { return [] }

        var routes: [SmartBridgeRoute] = []
        for target in targets.prefix(60) where target.id != source.id {
            let direct = score(from: source, to: target, intent: intent, feedback: feedback)
            if direct.total >= 0.62 {
                routes.append(route([source, target], intent: intent, feedback: feedback))
            }

            let mids = neighbors(
                for: source.id,
                in: [source] + pool,
                intent: intent,
                feedback: feedback,
                limit: 35
            )
            for mid in mids where mid.track.id != target.id {
                let second = score(from: mid.track, to: target, intent: intent, feedback: feedback)
                guard second.total >= 0.50 else { continue }
                routes.append(route([source, mid.track, target], intent: intent, feedback: feedback))
            }
        }

        var seen = Set<String>()
        return routes
            .filter { route in
                guard !seen.contains(route.id) else { return false }
                seen.insert(route.id)
                return Set(route.tracks.map(\.id)).count == route.tracks.count
            }
            .sorted { $0.totalCost < $1.totalCost }
            .prefix(limit)
            .map { $0 }
    }

    public static func draftWeakLinks(
        draft: SetaDraft,
        tracks: [SetaTrack],
        feedback: [String: TransitionFeedback] = [:]
    ) -> [DraftWeakLink] {
        let ordered = draft.resolvedTracks(from: tracks)
        guard ordered.count >= 2 else { return [] }
        var links: [DraftWeakLink] = []

        for index in 0 ..< ordered.count - 1 {
            let from = ordered[index]
            let to = ordered[index + 1]
            let score = score(from: from, to: to, intent: JourneyIntent(), feedback: feedback)
            guard score.total < weakLinkThreshold else { continue }
            let routes = bridgeRoutes(
                from: from.id,
                to: to.id,
                in: tracks,
                intent: JourneyIntent(mode: .bridge, targetTrackID: to.id),
                feedback: feedback,
                limit: 2
            ).filter { $0.tracks.count > 2 }

            var suggestions: [DraftSuggestion] = routes.map { route in
                DraftSuggestion(
                    id: "insert-\(route.id)",
                    kind: .insertBridge,
                    title: "Insert \(route.tracks.dropFirst().dropLast().map(\.displayTitle).joined(separator: " + "))",
                    trackIDs: route.tracks.dropFirst().dropLast().map(\.id),
                    route: route
                )
            }
            suggestions.append(
                DraftSuggestion(
                    id: "replace-\(from.id)-\(to.id)",
                    kind: .replaceNext,
                    title: "Try a stronger next candidate",
                    trackIDs: [],
                    route: nil
                )
            )
            links.append(
                DraftWeakLink(
                    id: "\(from.id)>\(to.id)",
                    from: from,
                    to: to,
                    score: score,
                    suggestions: suggestions
                )
            )
        }
        return links
    }

    private static func route(
        _ tracks: [SetaTrack],
        intent: JourneyIntent,
        feedback: [String: TransitionFeedback]
    ) -> SmartBridgeRoute {
        let transitions = zip(tracks, tracks.dropFirst()).map {
            score(from: $0.0, to: $0.1, intent: intent, feedback: feedback)
        }
        let cost = transitions.reduce(0.0) { partial, score in
            partial + (1 - score.total) + (score.confidence < 0.5 ? 0.2 : 0)
        }
        return SmartBridgeRoute(tracks: tracks, transitions: transitions, totalCost: cost)
    }

    private static func bridgeTargets(targetID: String?, pool: [SetaTrack], intent: JourneyIntent) -> [SetaTrack] {
        if let targetID, let target = pool.first(where: { $0.id == targetID }) {
            return [target]
        }
        if let momentID = intent.targetMomentID {
            return pool.filter { SetMoments.matchesAnyActiveMoments($0, activeMomentIDs: [momentID]) }
        }
        if let range = intent.targetBPMRange {
            return pool.filter { $0.bpm.map { range.contains($0) } == true }
        }
        return pool
    }

    private static func bpmScore(_ a: Double?, _ b: Double?, reasons: inout [String], warnings: inout [String]) -> Double {
        guard let a, let b else {
            warnings.append("missing BPM")
            return 0
        }
        let diff = b - a
        let absDiff = abs(diff)
        if absDiff <= 0.5 {
            reasons.append("same BPM")
        } else if absDiff <= 6 {
            reasons.append("\(diff >= 0 ? "+" : "")\(Int(diff.rounded())) BPM")
        } else {
            warnings.append("wide BPM jump")
        }
        return Camelot.bpmCompatible(a, b)
    }

    private static func energyDirectionScore(
        from source: SetaTrack,
        to target: SetaTrack,
        mode: JourneyMode,
        reasons: inout [String],
        warnings: inout [String]
    ) -> Double {
        let delta = target.effectiveEnergy - source.effectiveEnergy
        let absDelta = abs(delta)
        if delta > 0.05 { reasons.append("energy lift") }
        if delta < -0.08 { reasons.append("energy drop") }
        if absDelta > 0.35 { warnings.append("big energy jump") }

        switch mode {
        case .lift:
            return scoreWindow(delta, ideal: 0.14, tolerance: 0.22)
        case .closing:
            return scoreWindow(delta, ideal: -0.16, tolerance: 0.24)
        case .contrast:
            return clamp(absDelta / 0.35)
        case .smooth:
            return 1 - clamp(absDelta / 0.25)
        case .bridge:
            return 1 - clamp(max(0, absDelta - 0.04) / 0.34)
        case .journeyCoach:
            if delta >= 0 {
                return scoreWindow(delta, ideal: 0.10, tolerance: 0.26)
            }
            return 1 - clamp(absDelta / 0.32)
        }
    }

    private static func phraseEnergyFit(from source: SetaTrack, to target: SetaTrack, reasons: inout [String]) -> Double {
        let outro = source.energyOutro ?? source.effectiveEnergy
        let intro = target.energyIntro ?? target.effectiveEnergy
        let diff = abs(outro - intro)
        if diff <= 0.08 { reasons.append("outro fits intro") }
        return 1 - clamp(diff / 0.35)
    }

    private static func zoneScore(from source: SetaTrack, to target: SetaTrack, intent: JourneyIntent, reasons: inout [String]) -> Double {
        let sourceZones = matchingMomentIDs(source)
        let targetZones = matchingMomentIDs(target)
        if let targetMomentID = intent.targetMomentID {
            if targetZones.contains(targetMomentID) {
                reasons.append("target zone")
                return 1
            }
            return 0.35
        }
        if !sourceZones.isDisjoint(with: targetZones) {
            reasons.append("same zone")
            return 0.9
        }
        return 0.55
    }

    private static func genreSourceScore(from source: SetaTrack, to target: SetaTrack, reasons: inout [String]) -> Double {
        let sourceGenre = source.genre?.lowercased()
        let targetGenre = target.genre?.lowercased()
        if let sourceGenre, sourceGenre == targetGenre {
            reasons.append("same folder")
            return 0.85
        }
        if source.source != target.source {
            reasons.append("cross-source bridge")
            return 0.65
        }
        if source.batch != nil, source.batch == target.batch {
            reasons.append("same batch")
            return 0.8
        }
        return 0.45
    }

    private static func feedbackComponent(
        from source: SetaTrack,
        to target: SetaTrack,
        feedback: [String: TransitionFeedback],
        reasons: inout [String],
        warnings: inout [String]
    ) -> Double {
        let key = TransitionFeedback.key(from: source.id, to: target.id)
        guard let item = feedback[key] else { return 0.65 }
        if item.rating > 0 { reasons.append("approved before") }
        if item.rating < 0 { warnings.append("rejected before") }
        return Double(item.rating + 2) / 4.0
    }

    private static func hasVocalClash(_ source: SetaTrack, _ target: SetaTrack) -> Bool {
        source.vocals == "yes"
            && target.vocals == "yes"
            && (source.vocalsConfidence ?? 0) >= TrackPresentation.vocalsShowConfidence
            && (target.vocalsConfidence ?? 0) >= TrackPresentation.vocalsShowConfidence
    }

    private static func classifyKind(
        total: Double,
        source: SetaTrack,
        target: SetaTrack,
        intent: JourneyIntent,
        warnings: [String]
    ) -> TransitionKind {
        if total < weakLinkThreshold || warnings.contains("vocal risk") || warnings.contains("key clash") {
            return .risky
        }
        if intent.mode == .closing { return .closing }
        let delta = target.effectiveEnergy - source.effectiveEnergy
        if delta > 0.11 { return .lift }
        if abs(delta) > 0.24 { return .contrast }
        if source.genre != target.genre || source.source != target.source { return .bridge }
        return .smooth
    }

    private static func matchingMomentIDs(_ track: SetaTrack) -> Set<String> {
        Set(SetMoments.all.filter { SetMoments.matches(track, moment: $0) }.map(\.id))
    }

    private static func scoreWindow(_ value: Double, ideal: Double, tolerance: Double) -> Double {
        1 - clamp(abs(value - ideal) / tolerance)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func compact(_ values: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            out.append(value)
            if out.count >= limit { break }
        }
        return out
    }
}

public enum TransitionFeedbackStorage {
    public static let filename = "transition-feedback-v1.json"

    public static func load(from url: URL = defaultURL()) -> [String: TransitionFeedback] {
        guard let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([TransitionFeedback].self, from: data) else {
            return [:]
        }
        var feedback: [String: TransitionFeedback] = [:]
        for item in items {
            feedback[item.id] = item
        }
        return feedback
    }

    public static func save(_ feedback: [String: TransitionFeedback], to url: URL = defaultURL()) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let items = feedback.values.sorted { $0.updatedAt > $1.updatedAt }
            let data = try JSONEncoder().encode(items)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Feedback is helpful but should never block browsing or playback.
        }
    }

    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent("SetaMac", isDirectory: true).appendingPathComponent(filename)
    }
}

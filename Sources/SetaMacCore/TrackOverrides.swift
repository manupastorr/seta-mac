import Foundation

public struct TrackOverride: Codable, Equatable, Sendable {
    public var bpm: Double?
    public var key: String?
    public var energy: Double?

    public init(bpm: Double? = nil, key: String? = nil, energy: Double? = nil) {
        self.bpm = bpm
        self.key = key
        self.energy = energy
    }

    public var isEmpty: Bool {
        bpm == nil && key == nil && energy == nil
    }

    public static func normalized(
        bpm: Double? = nil,
        key: String? = nil,
        energy: Double? = nil
    ) -> TrackOverride {
        TrackOverride(
            bpm: bpm.map { min(MapPlotMetrics.bpmDomain.upperBound, max(MapPlotMetrics.bpmDomain.lowerBound, $0.rounded())) },
            key: key?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().nilIfEmpty,
            energy: energy.map { min(1, max(0, $0)) }
        )
    }
}

public enum TrackOverridesStorage {
    public static let storageKey = "seta-track-overrides-v1"
    public static let legacyEnergyKey = "seta-energy-overrides-v1"

    public static func load(from defaults: UserDefaults = .standard) -> [String: TrackOverride] {
        var overrides: [String: TrackOverride] = [:]

        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: TrackOverride].self, from: data) {
            overrides = decoded.compactMapValues { override in
                let normalized = TrackOverride.normalized(
                    bpm: override.bpm,
                    key: override.key,
                    energy: override.energy
                )
                return normalized.isEmpty ? nil : normalized
            }
        }

        if overrides.isEmpty,
           let legacy = defaults.dictionary(forKey: legacyEnergyKey) as? [String: Double] {
            for (trackId, energy) in legacy where energy.isFinite {
                let normalized = TrackOverride.normalized(energy: energy)
                if !normalized.isEmpty {
                    overrides[trackId] = normalized
                }
            }
            if !overrides.isEmpty {
                save(overrides, to: defaults)
                defaults.removeObject(forKey: legacyEnergyKey)
            }
        }

        return overrides
    }

    public static func save(_ overrides: [String: TrackOverride], to defaults: UserDefaults = .standard) {
        let cleaned = overrides.compactMapValues { override -> TrackOverride? in
            let normalized = TrackOverride.normalized(
                bpm: override.bpm,
                key: override.key,
                energy: override.energy
            )
            return normalized.isEmpty ? nil : normalized
        }
        guard let data = try? JSONEncoder().encode(cleaned) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

public extension Camelot {
    static let orderedCodes: [String] = (1 ... 11).flatMap { number in
        ["\(number)A", "\(number)B"]
    } + ["12A", "12B"]

    static func isKnownCode(_ code: String?) -> Bool {
        guard let code else { return false }
        return colors[code.uppercased()] != nil
    }
}

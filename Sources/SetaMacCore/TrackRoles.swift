import Foundation

public enum TrackRole: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case intro
    case opener
    case closer

    public var label: String {
        rawValue.capitalized
    }
}

public enum TrackRolesStorage {
    public static let storageKey = "seta-track-roles-v1"

    public static func load(from defaults: UserDefaults = .standard) -> [String: Set<TrackRole>] {
        guard let data = defaults.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode([String: [TrackRole]].self, from: data) else {
            return [:]
        }

        return stored.compactMapValues { roles in
            let normalized = Set(roles)
            return normalized.isEmpty ? nil : normalized
        }
    }

    public static func save(
        _ assignments: [String: Set<TrackRole>],
        to defaults: UserDefaults = .standard
    ) {
        let stored = assignments.compactMapValues { roles -> [TrackRole]? in
            let sorted = roles.sorted { $0.rawValue < $1.rawValue }
            return sorted.isEmpty ? nil : sorted
        }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

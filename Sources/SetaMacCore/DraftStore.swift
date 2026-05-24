import Foundation

public struct DraftStoreState: Codable, Equatable {
    public var activeId: String?
    public var drafts: [String: SetaDraft]

    public init(activeId: String? = nil, drafts: [String: SetaDraft] = [:]) {
        self.activeId = activeId
        self.drafts = drafts
    }
}

public enum DraftStore {
    public static let storageKey = "seta-drafts-v1"

    private struct PersistedPayload: Codable {
        var activeId: String?
        var drafts: [SetaDraft]
    }

    public static func newDraftId() -> String {
        "draft-\(String(Int(Date().timeIntervalSince1970 * 1000), radix: 36))"
    }

    public static func createDraft(name: String = "Set draft") -> SetaDraft {
        SetaDraft(id: newDraftId(), name: name)
    }

    public static func normalizeDraft(_ raw: SetaDraft?) -> SetaDraft? {
        guard let raw else { return nil }

        let trackIds = raw.trackIds.filter { !$0.isEmpty }
        let finalIds = raw.finalIds.filter { trackIds.contains($0) }
        let sortMode = DraftSortMode.allCases.contains(raw.sortMode) ? raw.sortMode : .energy
        let name = raw.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = raw.id.isEmpty ? newDraftId() : raw.id

        return SetaDraft(
            id: id,
            name: name.isEmpty ? "Set draft" : name,
            trackIds: trackIds,
            finalIds: finalIds,
            notes: raw.notes,
            sortMode: sortMode,
            updatedAt: raw.updatedAt
        )
    }

    public static func load(from defaults: UserDefaults = .standard) -> DraftStoreState {
        guard let data = defaults.data(forKey: storageKey) else {
            return DraftStoreState()
        }

        do {
            let payload = try JSONDecoder().decode(PersistedPayload.self, from: data)
            var drafts: [String: SetaDraft] = [:]
            for item in payload.drafts {
                guard let draft = normalizeDraft(item) else { continue }
                drafts[draft.id] = draft
            }

            var activeId = payload.activeId
            if let current = activeId, drafts[current] == nil {
                activeId = drafts.keys.first
            }
            if activeId == nil {
                activeId = drafts.keys.first
            }

            return DraftStoreState(activeId: activeId, drafts: drafts)
        } catch {
            return DraftStoreState()
        }
    }

    public static func save(_ store: DraftStoreState, to defaults: UserDefaults = .standard) {
        let payload = PersistedPayload(
            activeId: store.activeId,
            drafts: store.drafts.values.map { draft in
                SetaDraft(
                    id: draft.id,
                    name: draft.name,
                    trackIds: draft.trackIds,
                    finalIds: draft.finalIds,
                    notes: draft.notes,
                    sortMode: draft.sortMode,
                    updatedAt: draft.updatedAt
                )
            }
        )

        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: storageKey)
    }

    public static func activeDraft(from store: DraftStoreState) -> SetaDraft? {
        guard let activeId = store.activeId else { return nil }
        return store.drafts[activeId]
    }

    public static func ensureActiveDraft(
        _ store: inout DraftStoreState,
        defaultName: String = "Set draft"
    ) -> SetaDraft {
        if let draft = activeDraft(from: store) {
            return draft
        }

        let draft = createDraft(name: defaultName)
        store.drafts[draft.id] = draft
        store.activeId = draft.id
        return draft
    }

    public static func upsertActiveDraft(_ store: inout DraftStoreState, draft: SetaDraft) {
        store.drafts[draft.id] = draft
        store.activeId = draft.id
    }
}

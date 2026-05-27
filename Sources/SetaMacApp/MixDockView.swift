import AppKit
import SwiftUI
import SetaMacCore

struct MixDockTabs: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        GlassPanel(cornerRadius: 10, compact: true) {
            HStack(spacing: 6) {
                MixDockTabButton(
                    shortcut: "m",
                    title: "neighbors",
                    count: store.neighborResult.list.count,
                    isActive: store.mixDockExpanded && store.mixDockTab == .neighbors
                ) {
                    store.openMixDock(tab: .neighbors)
                }
                Text("·").font(.system(size: 10)).foregroundStyle(SetaTheme.muted)
                MixDockTabButton(
                    shortcut: "d",
                    title: "draft",
                    count: store.draft.trackIds.count,
                    isActive: store.mixDockExpanded && store.mixDockTab == .draft
                ) {
                    store.openMixDock(tab: .draft)
                }
            }
        }
    }
}

struct MixDockView: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    MixDockTabButton(
                        shortcut: "m",
                        title: "neighbors",
                        count: store.neighborResult.list.count,
                        isActive: store.mixDockTab == .neighbors
                    ) {
                        store.mixDockTab = .neighbors
                    }
                    Text("·").foregroundStyle(SetaTheme.muted)
                    MixDockTabButton(
                        shortcut: "d",
                        title: "draft",
                        count: store.draft.trackIds.count,
                        isActive: store.mixDockTab == .draft
                    ) {
                        store.mixDockTab = .draft
                    }
                    Spacer()
                    Button {
                        store.mixDockExpanded = false
                        store.queueFocusIndex = -1
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(SetaTheme.muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 8)

                ManualTrackControls(store: store)
                    .padding(.bottom, 8)

                if store.mixDockTab == .neighbors {
                    NeighborsPane(store: store)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    DraftPane(store: store)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: store.mixDockTab) { _, _ in
            store.initQueueFocusFromPlayback()
        }
    }
}

struct ManualTrackControls: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        if let track = store.selectedTrack {
            VStack(alignment: .leading, spacing: 8) {
                ManualOverrideRow(
                    title: "BPM",
                    valueText: track.bpm.map { "\(Int($0.rounded()))" } ?? "?",
                    isManual: store.trackOverride(for: track.id)?.bpm != nil,
                    onAuto: { store.clearManualBPM(for: track.id) }
                ) {
                    Slider(
                        value: Binding(
                            get: { track.bpm ?? MapPlotMetrics.bpmDomain.lowerBound },
                            set: { store.setManualBPM($0, for: track.id) }
                        ),
                        in: MapPlotMetrics.bpmDomain,
                        step: 1
                    )
                    .controlSize(.small)
                }

                ManualOverrideRow(
                    title: "Key",
                    isManual: store.trackOverride(for: track.id)?.key != nil,
                    onAuto: { store.clearManualKey(for: track.id) }
                ) {
                    CamelotKeyChip(
                        code: track.key ?? "?",
                        manual: store.trackOverride(for: track.id)?.key != nil
                    )
                } control: {
                    let selectedCode = track.key.flatMap { Camelot.isKnownCode($0) ? $0.uppercased() : nil }
                        ?? Camelot.orderedCodes[0]
                    Menu {
                        ForEach(Camelot.orderedCodes, id: \.self) { code in
                            Button {
                                store.setManualKey(code, for: track.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: Camelot.colorHex(code)))
                                        .frame(width: 8, height: 8)
                                    Text(code)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            CamelotKeyChip(code: selectedCode)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(SetaTheme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .menuStyle(.borderlessButton)
                }

                ManualOverrideRow(
                    title: "Intensity",
                    valueText: String(format: "%.2f", track.effectiveEnergy),
                    isManual: store.trackOverride(for: track.id)?.energy != nil || track.energyManual != nil,
                    onAuto: { store.clearManualEnergy(for: track.id) }
                ) {
                    Slider(
                        value: Binding(
                            get: { track.effectiveEnergy },
                            set: { store.setManualEnergy($0, for: track.id) }
                        ),
                        in: 0 ... 1,
                        step: 0.01
                    )
                    .controlSize(.small)
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.55))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(SetaTheme.panelBorder.opacity(0.8))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct ManualOverrideRow<ValueView: View, Control: View>: View {
    let title: String
    let isManual: Bool
    let onAuto: () -> Void
    @ViewBuilder var valueView: () -> ValueView
    @ViewBuilder var control: () -> Control

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SetaTheme.muted)
                Spacer()
                valueView()
                Button("Auto") { onAuto() }
                    .font(.system(size: 9, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(isManual ? SetaTheme.accent : SetaTheme.muted.opacity(0.55))
                    .disabled(!isManual)
            }
            control()
        }
    }
}

private extension ManualOverrideRow where ValueView == Text {
    init(
        title: String,
        valueText: String,
        isManual: Bool,
        onAuto: @escaping () -> Void,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.title = title
        self.isManual = isManual
        self.onAuto = onAuto
        self.valueView = {
            Text(valueText)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(SetaTheme.text)
        }
        self.control = control
    }
}

struct NeighborsPane: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                if !store.highlightNeighbors {
                    Text("Press n or pick Neighbors on a track.")
                        .font(.system(size: 11))
                        .foregroundStyle(SetaTheme.muted)
                        .padding(.top, 4)
                } else if let anchor = store.neighborAnchorID,
                          let anchorTrack = store.library?.tracks.first(where: { $0.id == anchor }) {
                    NeighborRow(
                        track: anchorTrack,
                        score: nil,
                        isAnchor: true,
                        isPlaying: store.playingTrackID == anchorTrack.id,
                        isInDraft: store.draft.trackIds.contains(anchorTrack.id),
                        isQueueFocus: store.queueFocusTrackID == anchorTrack.id,
                        onSelect: { reanchor in
                            store.playTrackViaView(id: anchorTrack.id, reanchor: reanchor)
                        },
                        onAdd: { store.addTrackToDraft(anchorTrack.id) }
                    )
                    if store.neighborResult.list.isEmpty {
                        Text("No mixable neighbors in current filters.")
                            .font(.system(size: 11))
                            .foregroundStyle(SetaTheme.muted)
                            .padding(.top, 4)
                    } else {
                        ForEach(Array(store.neighborResult.list.enumerated()), id: \.element.id) { index, track in
                            NeighborRow(
                                track: track,
                                rank: index + 1,
                                score: Playback.mixScore(anchorTrack, track),
                                isPlaying: store.playingTrackID == track.id,
                                isInDraft: store.draft.trackIds.contains(track.id),
                                isQueueFocus: store.queueFocusTrackID == track.id,
                                onSelect: { reanchor in
                                    store.playTrackViaView(id: track.id, reanchor: reanchor)
                                },
                                onAdd: { store.addTrackToDraft(track.id) }
                            )
                        }
                    }
                } else {
                    Text("Select a track on the map to see mix neighbors.")
                        .font(.system(size: 11))
                        .foregroundStyle(SetaTheme.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct DraftPane: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Set draft name", text: $store.draft.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SetaTheme.text)
                    .tint(SetaTheme.accent)
                    .onSubmit { store.persistDraftSoonViaView() }
                Text(draftCountLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(SetaTheme.muted)
            }
            HStack(spacing: 5) {
                draftSortChip("Energy", .energy)
                draftSortChip("BPM", .bpm)
                draftSortChip("Manual", .manual)
            }
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    SetaSecondaryButton(title: "Play draft", expand: true) { store.playDraftFromStart() }
                    SetaSecondaryButton(title: "Import Rekordbox", expand: true) { store.beginRekordboxImport() }
                }
                HStack(spacing: 5) {
                    SetaSecondaryButton(title: "Export M3U", expand: true) { store.exportDraftM3U() }
                    SetaSecondaryButton(title: "Copy list", expand: true) { store.copyDraftListToPasteboard() }
                }
            }
            if !store.draftTracks.isEmpty {
                DraftEnergyRampView(tracks: store.draftTracks)
            }
            if store.draftTracks.isEmpty {
                Text("No tracks yet — select a track and press a to add.")
                    .font(.system(size: 11))
                    .foregroundStyle(SetaTheme.muted)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(store.draftTracks.enumerated()), id: \.element.id) { index, track in
                            DraftTrackRow(
                                track: track,
                                isFinal: store.draft.finalIds.contains(track.id),
                                isSelected: store.selectedTrackID == track.id,
                                isPlaying: store.playingTrackID == track.id,
                                isQueueFocus: store.queueFocusTrackID == track.id,
                                note: store.draft.notes[track.id] ?? "",
                                onToggleFinal: { store.toggleFinal(track.id) },
                                onRemove: { store.removeFromDraft(track.id) },
                                onReorder: { draggedId in
                                    store.moveDraftTrack(id: draggedId, toIndex: index)
                                },
                                onNoteCommit: { store.setDraftNote($0, for: track.id) },
                                onSelect: { store.playDraftTrack(track.id) }
                            )
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var draftCountLabel: String {
        let count = store.draft.trackIds.count
        guard count > 0 else { return "" }
        let finals = store.draft.finalIds.count
        if finals > 0 { return "\(count) · \(finals) final" }
        return "\(count)"
    }

    private func draftSortChip(_ title: String, _ mode: DraftSortMode) -> some View {
        SetaChip(title: title, isActive: store.draft.sortMode == mode) {
            store.draft.sortMode = mode
            store.deferAfterListUpdate {
                store.syncPlayQueue()
                store.persistDraftSoonViaView()
            }
        }
    }
}

struct NeighborRow: View {
    let track: SetaTrack
    var rank: Int?
    var score: Double?
    var isAnchor: Bool = false
    let isPlaying: Bool
    let isInDraft: Bool
    var isQueueFocus: Bool = false
    let onSelect: (Bool) -> Void
    let onAdd: () -> Void

    @State private var isHovered = false

    private var rowAppearance: TrackListRowAppearance {
        TrackListRowAppearance(
            isHighlighted: isPlaying,
            isInDraft: isInDraft,
            isQueueFocus: isQueueFocus,
            isHovered: isHovered
        )
    }

    var body: some View {
        Button(action: { onSelect(NSEvent.modifierFlags.contains(.command)) }) {
            HStack(alignment: .center, spacing: 5) {
                Group {
                    if isAnchor {
                        Circle()
                            .fill(SetaTheme.accent)
                            .frame(width: 7, height: 7)
                    } else {
                        Text("\(rank ?? 0)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(SetaTheme.muted)
                    }
                }
                .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.displayTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SetaTheme.text)
                        .lineLimit(1)
                    Text(track.displayArtist)
                        .font(.system(size: 10))
                        .foregroundStyle(SetaTheme.muted)
                        .lineLimit(1)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                NeighborTrackMetaColumn(
                    track: track,
                    score: score,
                    inDraft: isInDraft,
                    anchor: isAnchor
                )
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background {
            TrackListRowChrome(appearance: rowAppearance)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Add to draft") { onAdd() }
        }
    }
}

struct DraftTrackRow: View {
    let track: SetaTrack
    let isFinal: Bool
    let isSelected: Bool
    let isPlaying: Bool
    var isQueueFocus: Bool = false
    let note: String
    let onToggleFinal: () -> Void
    let onRemove: () -> Void
    let onReorder: (String) -> Void
    let onNoteCommit: (String) -> Void
    var onSelect: () -> Void = {}

    @State private var noteText = ""
    @State private var isEditingNote = false
    @State private var isHovered = false
    @State private var removeHovered = false
    @State private var isDropTargeted = false
    @FocusState private var noteFieldFocused: Bool

    private var hasNoteContent: Bool {
        !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsNoteField: Bool {
        hasNoteContent || isEditingNote
    }

    private var rowAppearance: TrackListRowAppearance {
        TrackListRowAppearance(
            isHighlighted: isSelected || isPlaying,
            isQueueFocus: isQueueFocus,
            isHovered: isHovered
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 5) {
                Text("⋮⋮")
                    .font(.system(size: 12))
                    .foregroundStyle(SetaTheme.muted)
                    .opacity(isHovered ? 1 : 0.55)
                    .frame(width: 12)
                    .padding(.top, 1)
                    .contentShape(Rectangle())
                    .draggable(track.id) {
                        Text(track.displayTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SetaTheme.text)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                Button(action: onToggleFinal) {
                    Image(systemName: isFinal ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(isFinal ? SetaTheme.draftGold : SetaTheme.muted)
                }
                .buttonStyle(.plain)
                .padding(.top, 1)

                Button(action: onSelect) {
                    HStack(alignment: .center, spacing: 5) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.displayTitle)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(SetaTheme.text)
                                .lineLimit(1)
                            Text(track.displayArtist)
                                .font(.system(size: 10))
                                .foregroundStyle(SetaTheme.muted)
                                .lineLimit(1)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                        DraftTrackMetaColumn(track: track)
                    }
                }
                .buttonStyle(.plain)
                .frame(minWidth: 0, maxWidth: .infinity)

                if !showsNoteField {
                    Button {
                        isEditingNote = true
                        noteFieldFocused = true
                    } label: {
                        Image(systemName: "note.text")
                            .font(.system(size: 11))
                            .foregroundStyle(SetaTheme.muted.opacity(isHovered ? 0.85 : 0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Add note")
                    .padding(.top, 1)
                }

                Button(action: onRemove) {
                    Text("×")
                        .font(.system(size: 14))
                        .foregroundStyle(removeHovered ? Color(hex: "#c62828") : SetaTheme.muted)
                }
                .buttonStyle(.plain)
                .padding(.top, 1)
                .onHover { removeHovered = $0 }
            }

            if showsNoteField {
                TextField("Note…", text: $noteText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(SetaTheme.text)
                    .tint(SetaTheme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.9))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(SetaTheme.panelBorder)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .focused($noteFieldFocused)
                    .onSubmit { commitNote() }
                    .onChange(of: noteFieldFocused) { _, focused in
                        if !focused { commitNote() }
                    }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background {
            TrackListRowChrome(appearance: rowAppearance)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(SetaTheme.accent.opacity(0.85), lineWidth: 2)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let draggedId = items.first, draggedId != track.id else { return false }
            onReorder(draggedId)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .onHover { isHovered = $0 }
        .onAppear {
            if noteText.isEmpty { noteText = note }
        }
        .onChange(of: note) { _, newValue in
            noteText = newValue
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isEditingNote = false
            }
        }
    }

    private func commitNote() {
        onNoteCommit(noteText)
        if !hasNoteContent {
            isEditingNote = false
        }
    }
}

struct IssueList: View {
    let issues: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Library issues")
                .font(.headline)
            ForEach(issues, id: \.self) { issue in
                Text(issue)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

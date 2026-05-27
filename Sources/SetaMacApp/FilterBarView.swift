import SwiftUI
import SetaMacCore

enum FilterBarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { SetaTheme.filterBarHeight }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct FilterBarView: View {
    @ObservedObject var store: LibraryStore
    @FocusState.Binding var searchFocused: Bool
    @Binding var mapResetTrigger: UUID
    var compact: Bool = false

    var body: some View {
        FloatingChrome {
            HStack(alignment: .center, spacing: compact ? 8 : 12) {
                brandColumn

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 8) {
                        searchField
                        sourceChips
                        genrePicker
                        bpmControls
                        mapControls
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Button { store.showingLibraryFolders = true } label: {
                        Image(systemName: "folder.badge.gearshape")
                    }
                    .help("Library folders…")
                    Button { store.rescanLibrary() } label: {
                        if compact {
                            Image(systemName: "arrow.clockwise")
                        } else {
                            Label("Rescan", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(store.isRescanning || store.scannerRootURL == nil)
                    .help("Rescan library (pick up new tracks in incoming folders)")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(SetaTheme.muted)
                .fixedSize()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, compact ? 8 : 10)
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: FilterBarHeightPreferenceKey.self, value: proxy.size.height)
            }
        }
    }

    @ViewBuilder
    private var brandColumn: some View {
        if compact {
            Text("Seta 🍄")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(SetaTheme.text)
                .frame(width: 52, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Seta 🍄")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(SetaTheme.text)
                Text("BPM × intensity · mix hints")
                    .font(.system(size: 10))
                    .foregroundStyle(SetaTheme.muted)
            }
            .frame(width: SetaTheme.brandColumnWidth, alignment: .leading)
        }
    }

    private var searchField: some View {
        TextField("Artist or title…", text: $store.filter.query)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(SetaTheme.text)
            .tint(SetaTheme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(SetaTheme.panel)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(SetaTheme.panelBorder)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(width: compact ? 220 : SetaTheme.searchFieldWidth)
            .focused($searchFocused)
            .onChange(of: store.filter.query) { _, _ in
                store.resetSearchResultsIndex()
            }
            .onKeyPress(.upArrow) {
                guard !store.filter.query.trimmingCharacters(in: .whitespaces).isEmpty else { return .ignored }
                store.moveSearchResultsHighlight(delta: -1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                guard !store.filter.query.trimmingCharacters(in: .whitespaces).isEmpty else { return .ignored }
                store.moveSearchResultsHighlight(delta: 1)
                return .handled
            }
            .onKeyPress(.return) {
                guard !store.filter.query.trimmingCharacters(in: .whitespaces).isEmpty else { return .ignored }
                store.activateSearchResult()
                return .handled
            }
    }

    private var sourceChips: some View {
        HStack(spacing: 5) {
            if compact {
                SetaIconChip(systemImage: "square.grid.2x2", help: "All sources", isActive: allSourcesActive) {
                    store.filter.sources = ["tracks", "to_curate"]
                    store.filter.draftOnly = false
                    store.syncPlayQueue()
                }
                SetaIconChip(systemImage: "music.note.list", help: "Library", isActive: store.filter.sources == ["tracks"] && !store.filter.draftOnly) {
                    store.filter.sources = ["tracks"]
                    store.filter.draftOnly = false
                    store.syncPlayQueue()
                }
                SetaIconChip(systemImage: "tray.and.arrow.down", help: "Incoming", isActive: store.filter.sources == ["to_curate"] && !store.filter.draftOnly) {
                    store.filter.sources = ["to_curate"]
                    store.filter.draftOnly = false
                    store.syncPlayQueue()
                }
                SetaIconChip(
                    systemImage: "list.star",
                    help: "Draft only",
                    isActive: store.filter.draftOnly,
                    isDisabled: store.draft.trackIds.isEmpty
                ) {
                    store.filter.draftOnly.toggle()
                    store.syncPlayQueue()
                }
            } else {
                SetaChip(title: "All", isActive: allSourcesActive) {
                    store.filter.sources = ["tracks", "to_curate"]
                    store.filter.draftOnly = false
                    store.syncPlayQueue()
                }
                SetaChip(title: "Library", isActive: store.filter.sources == ["tracks"] && !store.filter.draftOnly) {
                    store.filter.sources = ["tracks"]
                    store.filter.draftOnly = false
                    store.syncPlayQueue()
                }
                SetaChip(title: "Incoming", isActive: store.filter.sources == ["to_curate"] && !store.filter.draftOnly) {
                    store.filter.sources = ["to_curate"]
                    store.filter.draftOnly = false
                    store.syncPlayQueue()
                }
                SetaChip(title: "Draft only", isActive: store.filter.draftOnly, isDisabled: store.draft.trackIds.isEmpty) {
                    store.filter.draftOnly.toggle()
                    store.syncPlayQueue()
                }
            }
        }
    }

    private var allSourcesActive: Bool {
        store.filter.sources == ["tracks", "to_curate"] && !store.filter.draftOnly
    }

    private var genrePicker: some View {
        Picker("Genre", selection: $store.filter.genre) {
            Text("All genres").tag("all")
            ForEach(store.availableGenres, id: \.self) { genre in
                Text(genre).tag(genre)
            }
        }
        .labelsHidden()
        .frame(width: compact ? 132 : 160)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(SetaTheme.panel)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(SetaTheme.panelBorder)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var bpmControls: some View {
        BpmRangeControl(
            minValue: $store.filter.bpmMin,
            maxValue: $store.filter.bpmMax,
            domain: MapPlotMetrics.bpmDomain,
            width: 162
        )
    }

    private var mapControls: some View {
        Group {
            if compact {
                SetaIconChip(systemImage: "arrow.counterclockwise", help: "Reset view") {
                    mapResetTrigger = UUID()
                }
            } else {
                SetaSecondaryButton(title: "Reset view") {
                    mapResetTrigger = UUID()
                }
            }
        }
    }
}

struct SearchResultsPopover: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        let results = store.searchResultTracks
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(results.enumerated()), id: \.element.id) { index, track in
                SearchResultRow(
                    track: track,
                    isHighlighted: index == store.searchResultsIndex,
                    isPlaying: store.playingTrackID == track.id,
                    onSelect: {
                        store.filter.query = ""
                        store.resetSearchResultsIndex()
                        store.playTrackViaView(id: track.id)
                    }
                )
            }
            if store.filteredTracks.count > results.count {
                Text("\(store.filteredTracks.count - results.count) more on the map…")
                    .font(.system(size: 10))
                    .foregroundStyle(SetaTheme.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            } else if results.isEmpty {
                Text("No matches")
                    .font(.system(size: 10))
                    .foregroundStyle(SetaTheme.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
        }
        .padding(4)
        .frame(minWidth: 280)
        .background(.white.opacity(0.98))
        .background(.ultraThinMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(SetaTheme.panelBorder)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
    }
}

struct SearchResultRow: View {
    let track: SetaTrack
    let isHighlighted: Bool
    let isPlaying: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    private var rowAppearance: TrackListRowAppearance {
        TrackListRowAppearance(
            isHighlighted: isHighlighted || isPlaying,
            isHovered: isHovered
        )
    }

    var body: some View {
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
                .frame(maxWidth: .infinity, alignment: .leading)

                NeighborTrackMetaColumn(track: track, score: nil, anchor: true)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background {
            TrackListRowChrome(appearance: rowAppearance, insetWidth: isHighlighted ? 3 : 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovered = $0 }
    }
}

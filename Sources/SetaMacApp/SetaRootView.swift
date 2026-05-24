import AppKit
import SwiftUI
import SetaMacCore
import UniformTypeIdentifiers

struct SetaRootView: View {
    @EnvironmentObject private var store: LibraryStore
    @State private var showingImporter = false
    @State private var mapResetTrigger = UUID()
    @State private var hoveredTrackID: String?
    @FocusState private var searchFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                TrackMapView(
                    tracks: store.filteredTracks,
                    selectedTrackID: $store.selectedTrackID,
                    hoveredTrackID: $hoveredTrackID,
                    playingTrackID: store.playingTrackID,
                    neighborHighlightIDs: store.neighborHighlightIDs,
                    neighborAnchorID: store.neighborAnchorID,
                    draftTrackIDs: store.draftTrackIDSet,
                    draftFinalIDs: store.draftFinalIDSet,
                    graphEdges: store.mapGraphEdges,
                    mixLinks: store.mixLinks,
                    showExploreLayout: store.settings.showExploreLinks,
                    showSetZoneOverlay: store.settings.showSetZoneOverlay,
                    activeMomentIDs: store.filter.moments,
                    energyDomain: store.energyDisplayDomain,
                    mixDockWidth: store.mixDockExpanded ? SetaTheme.mixDockWidth + 10 : 0,
                    bottomChrome: SetaTheme.playerHeight + 10,
                    resetTrigger: mapResetTrigger,
                    onPlayTrack: { store.playTrackViaView(id: $0) }
                )

                VStack(spacing: 0) {
                    FilterBarView(
                        store: store,
                        searchFocused: $searchFocused,
                        showingImporter: $showingImporter,
                        mapResetTrigger: $mapResetTrigger
                    )
                    Spacer(minLength: 0)
                    PlayerDock(store: store)
                }

                sidePanelsLayer(in: proxy.size)

                if store.highlightNeighbors {
                    NeighborModeCue()
                        .padding(.top, workspaceTopInset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

                StatusBanner(store: store)
                    .padding(.top, SetaTheme.filterBarHeight + (store.highlightNeighbors ? 38 : 10))
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(SetaTheme.background)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                _ = url.startAccessingSecurityScopedResource()
                store.load(url: url)
            }
        }
        .sheet(isPresented: $store.showShortcutsHelp) {
            ShortcutsHelpView()
        }
        .task {
            if store.library == nil {
                store.autoLoadLibraryIfPossible()
            }
        }
        .applyKeyboardShortcuts(store: store, mapResetTrigger: $mapResetTrigger, searchFocused: $searchFocused)
        .background(WindowTitleSetter(title: "Seta 🍄"))
    }

    private var workspaceTopInset: CGFloat { SetaTheme.filterBarHeight + 18 }
    private var workspaceBottomInset: CGFloat { SetaTheme.playerHeight + 24 }

    @ViewBuilder
    private func sidePanelsLayer(in size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            HStack(alignment: .top, spacing: 0) {
                mixDockLayer
                    .frame(
                        maxHeight: store.mixDockExpanded ? size.height - workspaceTopInset - workspaceBottomInset : nil,
                        alignment: .top
                    )
                    .padding(.leading, 10)
                    .padding(.top, workspaceTopInset)
                    .padding(.bottom, store.mixDockExpanded ? workspaceBottomInset : 0)

                Spacer(minLength: 0)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)

            legendsLayer
                .padding(.trailing, 18)
                .padding(.top, workspaceTopInset)
                .frame(width: size.width, height: size.height, alignment: .topTrailing)

            legendsBottomLayer
                .padding(.trailing, 18)
                .padding(.bottom, workspaceBottomInset)
                .frame(width: size.width, height: size.height, alignment: .bottomTrailing)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    @ViewBuilder
    private var legendsLayer: some View {
        if store.momentsLegendOpen {
            SetZonesLegend(store: store)
        } else {
            SetZonesLegendHeader(store: store)
        }
    }

    @ViewBuilder
    private var legendsBottomLayer: some View {
        if store.camelotLegendOpen {
            CamelotLegend(store: store)
        } else {
            CamelotLegendHeader(store: store)
        }
    }

    @ViewBuilder
    private var mixDockLayer: some View {
        if store.mixDockExpanded {
            MixDockView(store: store)
                .frame(width: SetaTheme.mixDockWidth)
        } else {
            MixDockTabs(store: store)
        }
    }
}

struct StatusBanner: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        if let message = store.errorMessage ?? store.statusMessage {
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(store.errorMessage == nil ? SetaTheme.muted : .orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.92))
                .background(.ultraThinMaterial, in: Capsule())
                .overlay { Capsule().strokeBorder(SetaTheme.panelBorder) }
                .onAppear {
                    guard store.errorMessage == nil else { return }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2.5))
                        if store.statusMessage == message {
                            store.statusMessage = nil
                        }
                    }
                }
        }
    }
}

private struct WindowTitleSetter: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { view.window?.title = title }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.title = title
    }
}

private struct KeyboardShortcutsModifier: ViewModifier {
    @ObservedObject var store: LibraryStore
    @Binding var mapResetTrigger: UUID
    var searchFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content
            .focusable()
            .onKeyPress(.space) { store.togglePlayPause(); return .handled }
            .onKeyPress(.leftArrow) {
                if NSEvent.modifierFlags.contains(.shift) { store.seekRelative(-10) }
                else { store.playRelative(step: -1) }
                return .handled
            }
            .onKeyPress(.rightArrow) {
                if NSEvent.modifierFlags.contains(.shift) { store.seekRelative(10) }
                else { store.playRelative(step: 1) }
                return .handled
            }
            .onKeyPress(.upArrow) {
                guard store.canQueueKeyboardNav, searchFocused.wrappedValue == false else { return .ignored }
                store.moveQueueFocus(step: -1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                guard store.canQueueKeyboardNav, searchFocused.wrappedValue == false else { return .ignored }
                store.moveQueueFocus(step: 1)
                return .handled
            }
            .onKeyPress(.return) {
                guard store.canQueueKeyboardNav, searchFocused.wrappedValue == false else { return .ignored }
                store.activateQueueFocus()
                return .handled
            }
            .onKeyPress("n") { store.toggleNeighborMode(); return .handled }
            .onKeyPress("a") { store.addSelectedToDraft(); return .handled }
            .onKeyPress("p") { store.playDraftFromStart(); return .handled }
            .onKeyPress("e") { store.sortDraftByEnergy(); return .handled }
            .onKeyPress("b") { store.sortDraftByBPM(); return .handled }
            .onKeyPress("m") { store.openMixDock(tab: .neighbors); return .handled }
            .onKeyPress("d") { store.openMixDock(tab: .draft); return .handled }
            .onKeyPress("k") { store.camelotLegendOpen.toggle(); return .handled }
            .onKeyPress("z") { store.momentsLegendOpen.toggle(); return .handled }
            .onKeyPress("r") { mapResetTrigger = UUID(); return .handled }
            .onKeyPress("/") { searchFocused.wrappedValue = true; return .handled }
            .onKeyPress("?") { store.showShortcutsHelp = true; return .handled }
    }
}

private extension View {
    func applyKeyboardShortcuts(
        store: LibraryStore,
        mapResetTrigger: Binding<UUID>,
        searchFocused: FocusState<Bool>.Binding
    ) -> some View {
        modifier(KeyboardShortcutsModifier(store: store, mapResetTrigger: mapResetTrigger, searchFocused: searchFocused))
    }
}

struct NeighborModeCue: View {
    var body: some View {
        Button {} label: {
            HStack(spacing: 4) {
                SetaKbd(text: "n")
                Text("neighbors on")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SetaTheme.muted)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(.white.opacity(0.78))
            .background(.ultraThinMaterial, in: Capsule())
            .overlay { Capsule().strokeBorder(SetaTheme.panelBorder) }
            .shadow(color: .black.opacity(0.06), radius: 10, y: 2)
        }
        .buttonStyle(.plain)
    }
}

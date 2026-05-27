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
    @State private var isWindowFullscreen = false

    var body: some View {
        workspace
            .frame(minWidth: SetaTheme.minWindowWidth, minHeight: SetaTheme.minWindowHeight)
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
            .sheet(isPresented: $store.showingRekordboxImport) {
                RekordboxImportSheet(store: store)
            }
            .sheet(isPresented: $store.showingLibraryFolders) {
                LibraryFoldersSheet(store: store)
            }
            .task {
                if store.library == nil {
                    store.autoLoadLibraryIfPossible()
                }
                if store.needsFolderSetup {
                    store.showingLibraryFolders = true
                }
            }
            .applyKeyboardShortcuts(store: store, mapResetTrigger: $mapResetTrigger, searchFocused: $searchFocused)
            .background(WindowTitleSetter(title: "Seta 🍄"))
    }

    private var workspace: some View {
        GeometryReader { proxy in
            let compactToolbar = !isWindowFullscreen || proxy.size.width < SetaTheme.compactToolbarWidth

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
                    mixLinks: store.mixLinks,
                    showSetZoneOverlay: store.settings.showSetZoneOverlay,
                    activeMomentIDs: store.filter.moments,
                    energyDomain: store.energyDisplayDomain,
                    mixDockWidth: store.mixDockExpanded ? SetaTheme.mixDockWidth + 10 : 0,
                    rightChrome: mapRightChrome,
                    bottomChrome: SetaTheme.playerHeight + 10,
                    resetTrigger: mapResetTrigger,
                    trackOverrides: store.trackOverrides,
                    onPlayTrack: { store.playTrackViaView(id: $0) }
                )

                VStack(spacing: 0) {
                    FilterBarView(
                        store: store,
                        searchFocused: $searchFocused,
                        showingImporter: $showingImporter,
                        mapResetTrigger: $mapResetTrigger,
                        compact: compactToolbar
                    )
                    Spacer(minLength: 0)
                    PlayerDock(store: store)
                }

                sidePanelsLayer(in: proxy.size)
                searchResultsLayer

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
        .background(WindowLayoutTracker(isFullscreen: $isWindowFullscreen))
    }

    private var mapRightChrome: CGFloat {
        if store.momentsLegendOpen || store.camelotLegendOpen {
            return SetaTheme.legendWidth + 42
        }
        return SetaTheme.legendHeaderChrome
    }

    private var workspaceTopInset: CGFloat { SetaTheme.filterBarHeight + 18 }
    private var workspaceBottomInset: CGFloat { SetaTheme.playerHeight + 24 }

    @ViewBuilder
    private var searchResultsLayer: some View {
        if !store.filter.query.trimmingCharacters(in: .whitespaces).isEmpty {
            SearchResultsPopover(store: store)
                .frame(width: SetaTheme.searchFieldWidth + 28, alignment: .topLeading)
                .padding(.leading, SetaTheme.searchPopoverLeft)
                .padding(.top, SetaTheme.filterBarHeight + 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .zIndex(40)
        }
    }

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
    @State private var dismissTask: Task<Void, Never>?

    private var message: String? {
        store.errorMessage ?? store.statusMessage
    }

    var body: some View {
        if let message {
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(store.errorMessage == nil ? SetaTheme.muted : .orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.92))
                .background(.ultraThinMaterial, in: Capsule())
                .overlay { Capsule().strokeBorder(SetaTheme.panelBorder) }
                .id(message)
                .onAppear { scheduleDismiss(for: message) }
                .onChange(of: message) { _, newMessage in
                    scheduleDismiss(for: newMessage)
                }
                .onDisappear {
                    dismissTask?.cancel()
                    dismissTask = nil
                }
        }
    }

    private func scheduleDismiss(for message: String) {
        guard store.errorMessage == nil else { return }
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            if store.errorMessage == nil, store.statusMessage == message {
                store.statusMessage = nil
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

private struct WindowLayoutTracker: NSViewRepresentable {
    @Binding var isFullscreen: Bool

    func makeNSView(context: Context) -> FullscreenObserverView {
        FullscreenObserverView()
    }

    func updateNSView(_ nsView: FullscreenObserverView, context: Context) {
        nsView.onFullscreenChange = { value in
            isFullscreen = value
        }
        nsView.publishFullscreenState()
    }
}

private final class FullscreenObserverView: NSView {
    var onFullscreenChange: ((Bool) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        registerWindowObservers()
        publishFullscreenState()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let window {
            NotificationCenter.default.removeObserver(self, name: nil, object: window)
        }
        super.viewWillMove(toWindow: newWindow)
    }

    @objc func publishFullscreenState() {
        onFullscreenChange?(window?.styleMask.contains(.fullScreen) == true)
    }

    private func registerWindowObservers() {
        guard let window else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(publishFullscreenState),
            name: NSWindow.didEnterFullScreenNotification,
            object: window
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(publishFullscreenState),
            name: NSWindow.didExitFullScreenNotification,
            object: window
        )
    }
}

private struct KeyboardShortcutsModifier: ViewModifier {
    @ObservedObject var store: LibraryStore
    @Binding var mapResetTrigger: UUID
    var searchFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content
            .focusable()
            .onKeyPress(.space) {
                guard canUseGlobalShortcut else { return .ignored }
                store.togglePlayPause()
                return .handled
            }
            .onKeyPress(.leftArrow) {
                guard canUseGlobalShortcut else { return .ignored }
                if NSEvent.modifierFlags.contains(.shift) { store.seekRelative(-10) }
                else { store.playRelative(step: -1) }
                return .handled
            }
            .onKeyPress(.rightArrow) {
                guard canUseGlobalShortcut else { return .ignored }
                if NSEvent.modifierFlags.contains(.shift) { store.seekRelative(10) }
                else { store.playRelative(step: 1) }
                return .handled
            }
            .onKeyPress(.upArrow) {
                guard store.canQueueKeyboardNav, canUseGlobalShortcut else { return .ignored }
                store.moveQueueFocus(step: -1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                guard store.canQueueKeyboardNav, canUseGlobalShortcut else { return .ignored }
                store.moveQueueFocus(step: 1)
                return .handled
            }
            .onKeyPress(.return) {
                guard canUseGlobalShortcut else { return .ignored }
                if NSEvent.modifierFlags.contains(.command) {
                    store.reanchorFromShortcut()
                    return .handled
                }
                guard store.canQueueKeyboardNav else { return .ignored }
                store.activateQueueFocus()
                return .handled
            }
            .onKeyPress("n") { handleGlobalShortcut { store.toggleNeighborMode() } }
            .onKeyPress("a") { handleGlobalShortcut { store.addSelectedToDraft() } }
            .onKeyPress("p") { handleGlobalShortcut { store.playDraftFromStart() } }
            .onKeyPress("e") { handleGlobalShortcut { store.sortDraftByEnergy() } }
            .onKeyPress("b") { handleGlobalShortcut { store.sortDraftByBPM() } }
            .onKeyPress("m") { handleGlobalShortcut { store.openMixDock(tab: .neighbors) } }
            .onKeyPress("d") { handleGlobalShortcut { store.openMixDock(tab: .draft) } }
            .onKeyPress("k") { handleGlobalShortcut { store.camelotLegendOpen.toggle() } }
            .onKeyPress("z") { handleGlobalShortcut { store.momentsLegendOpen.toggle() } }
            .onKeyPress("r") { handleGlobalShortcut { mapResetTrigger = UUID() } }
            .onKeyPress("/") {
                guard canUseGlobalShortcut else { return .ignored }
                searchFocused.wrappedValue = true
                return .handled
            }
            .onKeyPress("?") { handleGlobalShortcut { store.showShortcutsHelp = true } }
    }

    private var canUseGlobalShortcut: Bool {
        !searchFocused.wrappedValue && !isEditingText
    }

    private var isEditingText: Bool {
        NSApp.keyWindow?.firstResponder is NSTextView
    }

    private func handleGlobalShortcut(_ action: () -> Void) -> KeyPress.Result {
        guard canUseGlobalShortcut else { return .ignored }
        action()
        return .handled
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
                Text("matches on")
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

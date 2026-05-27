import AppKit
import SwiftUI

@main
struct SetaMacApp: App {
    @StateObject private var store = LibraryStore()

    var body: some Scene {
        WindowGroup {
            SetaRootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
                .frame(minWidth: SetaTheme.minWindowWidth, minHeight: SetaTheme.minWindowHeight)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Toggle Full Screen") {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
            }
            CommandMenu("Library") {
                Button("Library Folders…") { store.showingLibraryFolders = true }
                Button("Rescan Library") { store.rescanLibrary() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            CommandMenu("Playback") {
                Button("Play / Pause") { store.togglePlayPause() }
                Button("Previous Track") { store.playRelative(step: -1) }
                Button("Next Track") { store.playRelative(step: 1) }
                Button("Seek Back 10s") { store.seekRelative(-10) }
                Button("Seek Forward 10s") { store.seekRelative(10) }
            }
            CommandMenu("Setlist") {
                Button("Add Selected To Setlist") { store.addSelectedToDraft() }
                Button("Play Setlist") { store.playDraftFromStart() }
                Button("Sort Setlist By Energy") { store.sortDraftByEnergy() }
                Button("Sort Setlist By BPM") { store.sortDraftByBPM() }
            }
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") { store.showShortcutsHelp = true }
            }
        }
    }
}

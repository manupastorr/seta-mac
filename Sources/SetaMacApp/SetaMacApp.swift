import SwiftUI

@main
struct SetaMacApp: App {
    @StateObject private var store = LibraryStore()

    var body: some Scene {
        WindowGroup {
            SetaRootView()
                .environmentObject(store)
                .frame(minWidth: 1180, minHeight: 760)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Library") {
                Button("Rescan Library") { store.rescanLibrary() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Rescan With Mix Edges") { store.rescanLibrary(fullEdges: true) }
            }
            CommandMenu("Playback") {
                Button("Play / Pause") { store.togglePlayPause() }
                    .keyboardShortcut(.space, modifiers: [])
                Button("Previous Track") { store.playRelative(step: -1) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Next Track") { store.playRelative(step: 1) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("Seek Back 10s") { store.seekRelative(-10) }
                    .keyboardShortcut(.leftArrow, modifiers: .shift)
                Button("Seek Forward 10s") { store.seekRelative(10) }
                    .keyboardShortcut(.rightArrow, modifiers: .shift)
            }
            CommandMenu("Draft") {
                Button("Add Selected To Draft") { store.addSelectedToDraft() }
                    .keyboardShortcut("a", modifiers: [])
                Button("Play Draft") { store.playDraftFromStart() }
                    .keyboardShortcut("p", modifiers: [])
                Button("Sort Draft By Energy") { store.sortDraftByEnergy() }
                    .keyboardShortcut("e", modifiers: [])
                Button("Sort Draft By BPM") { store.sortDraftByBPM() }
                    .keyboardShortcut("b", modifiers: [])
            }
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") { store.showShortcutsHelp = true }
                    .keyboardShortcut("?", modifiers: [])
            }
        }
    }
}

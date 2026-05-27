import AppKit
import SwiftUI
import SetaMacCore

struct LibraryFoldersSheet: View {
    @ObservedObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SetaSheetLayout(
            title: "Library folders",
            subtitle: "Recursive scan. Removing folders or hiding tracks never deletes files on disk.",
            width: 620
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    folderSourceCard(
                        icon: "music.note.list",
                        title: "Library",
                        subtitle: "Curated collection",
                        folders: store.settings.tracksFolders,
                        onAdd: { pickFolder { store.addTracksFolder(url: $0, bookmarkData: $1) } },
                        onRemove: { store.removeTracksFolder(id: $0) }
                    )

                    folderSourceCard(
                        icon: "tray.and.arrow.down.fill",
                        title: "Incoming",
                        subtitle: "Downloads to review",
                        folders: store.settings.curateFolders,
                        onAdd: { pickFolder { store.addCurateFolder(url: $0, bookmarkData: $1) } },
                        onRemove: { store.removeCurateFolder(id: $0) }
                    )
                }

                hiddenTracksRow
            }
        } footer: {
            footerBar
        }
    }

    @ViewBuilder
    private func folderSourceCard(
        icon: String,
        title: String,
        subtitle: String,
        folders: [LibraryFolderEntry],
        onAdd: @escaping () -> Void,
        onRemove: @escaping (String) -> Void
    ) -> some View {
        SetaSheetSectionCard(icon: icon, title: title, subtitle: subtitle, compact: true) {
            VStack(alignment: .leading, spacing: 6) {
                if folders.isEmpty {
                    Button(action: onAdd) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 12))
                            Text("Add folder…")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(SetaTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(spacing: 4) {
                        ForEach(folders) { folder in
                            LibraryFolderRow(
                                folder: folder,
                                onReveal: { revealInFinder(path: folder.path) },
                                onRemove: { onRemove(folder.id) }
                            )
                        }
                    }

                    Button(action: onAdd) {
                        Label("Add folder…", systemImage: "plus")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SetaTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hiddenTracksRow: some View {
        SetaSheetSectionCard(
            icon: "eye.slash",
            title: "Hidden tracks",
            subtitle: "Restore, then rescan",
            compact: true
        ) {
            if store.excludedTrackPathsSorted.isEmpty {
                Text("None hidden.")
                    .font(.system(size: 11))
                    .foregroundStyle(SetaTheme.muted)
            } else if store.excludedTrackPathsSorted.count == 1,
                      let path = store.excludedTrackPathsSorted.first {
                HiddenTrackRow(path: path) {
                    store.restoreExcludedTrack(path: path)
                }
            } else {
                Menu {
                    ForEach(store.excludedTrackPathsSorted, id: \.self) { path in
                        Button(URL(fileURLWithPath: path).lastPathComponent) {
                            store.restoreExcludedTrack(path: path)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("\(store.excludedTrackPathsSorted.count) hidden")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(SetaTheme.text)
                        Text("Restore…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(SetaTheme.accent)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(SetaTheme.muted)
                    }
                }
                .menuStyle(.borderlessButton)
            }
        }
    }

    private var footerBar: some View {
        HStack(alignment: .center, spacing: 12) {
            if !store.settings.hasConfiguredFolders {
                Label("Add at least one folder", systemImage: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            } else if store.isRescanning {
                ProgressView()
                    .controlSize(.small)
                Text("Scanning…")
                    .font(.system(size: 11))
                    .foregroundStyle(SetaTheme.muted)
            }

            Spacer(minLength: 0)

            SetaSecondaryButton(title: "Close") { dismiss() }

            Button("Rescan library") {
                dismiss()
                store.rescanLibrary()
            }
            .buttonStyle(.borderedProminent)
            .tint(SetaTheme.accent)
            .keyboardShortcut(.defaultAction)
            .disabled(
                store.isRescanning
                    || store.scannerRootURL == nil
                    || !store.settings.hasConfiguredFolders
            )
        }
    }

    private func revealInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func pickFolder(onPick: @escaping (URL, Data?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        panel.message = "Choose a folder to scan recursively."
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            let bookmark = FolderBookmarkAccess.bookmarkData(for: url)
            onPick(url, bookmark)
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
}

private struct LibraryFolderRow: View {
    let folder: LibraryFolderEntry
    let onReveal: () -> Void
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundStyle(SetaTheme.accent.opacity(0.9))
                .frame(width: 26, height: 26)
                .background(SetaTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(folder.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SetaTheme.text)
                    .lineLimit(1)
                Text(folder.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(SetaTheme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                SheetIconButton(systemImage: "arrow.up.forward.square", help: "Show in Finder", action: onReveal)
                SheetIconButton(systemImage: "minus.circle", help: "Stop scanning", action: onRemove)
            }
            .opacity(isHovered ? 1 : 0.7)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isHovered ? Color.white.opacity(0.9) : Color.white.opacity(0.65))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(SetaTheme.panelBorder.opacity(isHovered ? 1 : 0.7))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovered = $0 }
    }
}

private struct HiddenTrackRow: View {
    let path: String
    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(URL(fileURLWithPath: path).lastPathComponent)
                .font(.system(size: 11))
                .foregroundStyle(SetaTheme.text)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button("Restore", action: onRestore)
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SetaTheme.accent)
        }
    }
}

private struct SheetIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SetaTheme.muted)
                .frame(width: 24, height: 24)
                .background(SetaTheme.panel)
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(SetaTheme.panelBorder)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

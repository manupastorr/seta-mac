import AppKit
import SwiftUI
import SetaMacCore

struct LibraryFoldersSheet: View {
    @ObservedObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SetaSheetLayout(
            title: "Library folders",
            subtitle: "Choose where Seta scans for music. Subfolders are included. Removing a folder or hiding a track never deletes files on disk.",
            maxContentHeight: 400
        ) {
            VStack(alignment: .leading, spacing: 14) {
                folderSourceCard(
                    icon: "music.note.list",
                    title: "Library",
                    subtitle: "Approved tracks in your main collection",
                    folders: store.settings.tracksFolders,
                    emptyHint: "Add your curated library root (e.g. Music/tracks).",
                    onAdd: { pickFolder { store.addTracksFolder(url: $0, bookmarkData: $1) } },
                    onRemove: { store.removeTracksFolder(id: $0) }
                )

                folderSourceCard(
                    icon: "tray.and.arrow.down.fill",
                    title: "Incoming",
                    subtitle: "Downloads and batches still being reviewed",
                    folders: store.settings.curateFolders,
                    emptyHint: "Add an intake folder (e.g. Downloads/To Curate).",
                    onAdd: { pickFolder { store.addCurateFolder(url: $0, bookmarkData: $1) } },
                    onRemove: { store.removeCurateFolder(id: $0) }
                )

                hiddenTracksCard
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
        emptyHint: String,
        onAdd: @escaping () -> Void,
        onRemove: @escaping (String) -> Void
    ) -> some View {
        SetaSheetSectionCard(icon: icon, title: title, subtitle: subtitle) {
            VStack(alignment: .leading, spacing: 8) {
                if folders.isEmpty {
                    emptyFolderPlaceholder(hint: emptyHint, onAdd: onAdd)
                } else {
                    VStack(spacing: 6) {
                        ForEach(folders) { folder in
                            LibraryFolderRow(
                                folder: folder,
                                onReveal: { revealInFinder(path: folder.path) },
                                onRemove: { onRemove(folder.id) }
                            )
                        }
                    }
                }

                Button(action: onAdd) {
                    Label("Add folder…", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SetaTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var hiddenTracksCard: some View {
        SetaSheetSectionCard(
            icon: "eye.slash",
            title: "Hidden tracks",
            subtitle: "Excluded from the map and lists. Restore, then rescan."
        ) {
            if store.excludedTrackPathsSorted.isEmpty {
                Text("No hidden tracks.")
                    .font(.system(size: 11))
                    .foregroundStyle(SetaTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(store.excludedTrackPathsSorted, id: \.self) { path in
                            HiddenTrackRow(path: path) {
                                store.restoreExcludedTrack(path: path)
                            }
                        }
                    }
                }
                .frame(maxHeight: 120)
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

    @ViewBuilder
    private func emptyFolderPlaceholder(hint: String, onAdd: @escaping () -> Void) -> some View {
        Button(action: onAdd) {
            VStack(spacing: 6) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 22))
                    .foregroundStyle(SetaTheme.muted.opacity(0.85))
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(SetaTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.55))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(SetaTheme.panelBorder, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
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
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.system(size: 14))
                .foregroundStyle(SetaTheme.accent.opacity(0.9))
                .frame(width: 32, height: 32)
                .background(SetaTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SetaTheme.text)
                    .lineLimit(1)
                Text(folder.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SetaTheme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                SetaIconChip(systemImage: "arrow.up.forward.square", help: "Show in Finder", action: onReveal)
                SetaIconChip(systemImage: "minus.circle", help: "Stop scanning this folder", action: onRemove)
            }
            .opacity(isHovered ? 1 : 0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isHovered ? Color.white.opacity(0.9) : Color.white.opacity(0.65))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(SetaTheme.panelBorder.opacity(isHovered ? 1 : 0.7))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { isHovered = $0 }
    }
}

private struct HiddenTrackRow: View {
    let path: String
    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 11))
                .foregroundStyle(SetaTheme.muted)
                .frame(width: 18)

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
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

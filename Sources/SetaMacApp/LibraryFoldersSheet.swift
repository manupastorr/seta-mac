import AppKit
import SwiftUI
import SetaMacCore

struct LibraryFoldersSheet: View {
    @ObservedObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Library folders")
                    .font(.system(size: 18, weight: .bold))
                Text("Add curated and incoming folders. Seta scans subfolders recursively. Removing folders or tracks does not delete audio files.")
                    .font(.system(size: 12))
                    .foregroundStyle(SetaTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            folderSection(
                title: "Library",
                subtitle: "Approved / curated music",
                folders: store.settings.tracksFolders,
                onAdd: { pickFolder { store.addTracksFolder(url: $0, bookmarkData: $1) } },
                onRemove: { store.removeTracksFolder(id: $0) }
            )

            folderSection(
                title: "Incoming",
                subtitle: "Downloads and batches to review",
                folders: store.settings.curateFolders,
                onAdd: { pickFolder { store.addCurateFolder(url: $0, bookmarkData: $1) } },
                onRemove: { store.removeCurateFolder(id: $0) }
            )

            excludedSection

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                Button("Rescan library") {
                    dismiss()
                    store.rescanLibrary()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(store.isRescanning || store.scannerRootURL == nil || !store.settings.hasConfiguredFolders)
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    @ViewBuilder
    private func folderSection(
        title: String,
        subtitle: String,
        folders: [LibraryFolderEntry],
        onAdd: @escaping () -> Void,
        onRemove: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(SetaTheme.muted)
                }
                Spacer()
                Button("Add folder…", action: onAdd)
            }

            if folders.isEmpty {
                Text("No folders yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(SetaTheme.muted)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 4) {
                    ForEach(folders) { folder in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(folder.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                Text(folder.path)
                                    .font(.system(size: 10))
                                    .foregroundStyle(SetaTheme.muted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button("Remove") {
                                onRemove(folder.id)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(SetaTheme.muted)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(SetaTheme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    private var excludedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hidden tracks")
                .font(.system(size: 13, weight: .semibold))
            Text("Tracks hidden from Seta. Restore them here, then rescan.")
                .font(.system(size: 11))
                .foregroundStyle(SetaTheme.muted)

            if store.excludedTrackPathsSorted.isEmpty {
                Text("None hidden.")
                    .font(.system(size: 11))
                    .foregroundStyle(SetaTheme.muted)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(store.excludedTrackPathsSorted, id: \.self) { path in
                            HStack(spacing: 8) {
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                Spacer()
                                Button("Restore") {
                                    store.restoreExcludedTrack(path: path)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                .frame(maxHeight: 100)
            }
        }
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

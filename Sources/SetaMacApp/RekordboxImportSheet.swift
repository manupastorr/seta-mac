import SwiftUI
import SetaMacCore
import UniformTypeIdentifiers

struct RekordboxImportSheet: View {
    @ObservedObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Import Rekordbox playlist")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Choose file…") {
                    selectedIndex = nil
                    store.showingRekordboxFileImporter = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(SetaTheme.accent)
            }

            Text("Select one playlist. Only tracks already in your Seta library are imported.")
                .font(.system(size: 11))
                .foregroundStyle(SetaTheme.muted)

            if let message = store.rekordboxImportMessage,
               store.rekordboxImportCandidates.isEmpty,
               !store.isLoadingRekordboxImport {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(SetaTheme.muted)
                    .padding(.vertical, 4)
            }

            if store.isLoadingRekordboxImport {
                Spacer(minLength: 0)
                ProgressView("Loading Rekordbox playlists…")
                    .font(.system(size: 11))
                    .foregroundStyle(SetaTheme.muted)
                    .frame(maxWidth: .infinity)
            } else if store.rekordboxImportCandidates.isEmpty {
                Spacer(minLength: 0)
                Text("Export an M3U from Rekordbox, or use a Rekordbox XML export.")
                    .font(.system(size: 11))
                    .foregroundStyle(SetaTheme.muted)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(store.rekordboxImportCandidates.enumerated()), id: \.offset) { index, candidate in
                            RekordboxImportRow(
                                candidate: candidate,
                                matchedCount: store.rekordboxMatchedCount(at: index),
                                isSelected: selectedIndex == index
                            ) {
                                selectedIndex = index
                            }
                        }
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Import") { importSelection() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canImportSelection)
            }
        }
        .padding(16)
        .frame(width: 360, height: 320)
        .onChange(of: store.rekordboxImportCandidates.count) { _, _ in
            selectedIndex = defaultSelectionIndex
        }
        .onAppear {
            selectedIndex = defaultSelectionIndex
        }
        .fileImporter(
            isPresented: $store.showingRekordboxFileImporter,
            allowedContentTypes: [.m3uPlaylist, .m3u8Playlist, .xml, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                selectedIndex = nil
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }
                store.importRekordboxFile(url: url)
            }
        }
    }

    private var defaultSelectionIndex: Int? {
        store.rekordboxImportCandidates.indices.first {
            store.rekordboxMatchedCount(at: $0) > 0
        }
    }

    private var canImportSelection: Bool {
        guard let selectedIndex else { return false }
        return store.rekordboxImportCandidates.indices.contains(selectedIndex)
            && store.rekordboxMatchedCount(at: selectedIndex) > 0
    }

    private func importSelection() {
        guard let selectedIndex,
              store.rekordboxImportCandidates.indices.contains(selectedIndex) else { return }
        store.importRekordboxCandidate(store.rekordboxImportCandidates[selectedIndex])
        dismiss()
    }
}

private struct RekordboxImportRow: View {
    let candidate: PlaylistImportCandidate
    let matchedCount: Int
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? SetaTheme.accent : SetaTheme.muted)

                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SetaTheme.text)
                        .lineLimit(1)
                    Text(summary)
                        .font(.system(size: 10))
                        .foregroundStyle(matchedCount > 0 ? SetaTheme.muted : .orange)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(rowBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? SetaTheme.accent.opacity(0.45) : Color.clear, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(matchedCount == 0)
        .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if isSelected {
            return SetaTheme.accentSoft
        }
        return isHovered ? SetaTheme.panelElevated.opacity(0.75) : SetaTheme.panelElevated.opacity(0.45)
    }

    private var summary: String {
        if matchedCount == 0 {
            return "\(candidate.paths.count) tracks · none in Seta library"
        }
        if matchedCount == candidate.paths.count {
            return "\(matchedCount) tracks"
        }
        return "\(matchedCount) of \(candidate.paths.count) tracks in Seta library"
    }
}

private extension UTType {
    static let m3uPlaylist = UTType(filenameExtension: "m3u") ?? .plainText
    static let m3u8Playlist = UTType(filenameExtension: "m3u8") ?? .plainText
}

import SwiftUI
import SetaMacCore
import UniformTypeIdentifiers

struct RekordboxImportSheet: View {
    @ObservedObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Import Rekordbox playlist")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Choose file…") {
                    store.showingRekordboxFileImporter = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(SetaTheme.accent)
            }

            Text("Only tracks already in your Seta library are imported.")
                .font(.system(size: 11))
                .foregroundStyle(SetaTheme.muted)

            if let message = store.rekordboxImportMessage, store.rekordboxImportCandidates.isEmpty {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(SetaTheme.muted)
                    .padding(.vertical, 4)
            }

            if store.rekordboxImportCandidates.isEmpty {
                Spacer(minLength: 0)
                Text("Export an M3U from Rekordbox, or use a Rekordbox XML export.")
                    .font(.system(size: 11))
                    .foregroundStyle(SetaTheme.muted)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.rekordboxImportCandidates) { candidate in
                            RekordboxImportRow(
                                candidate: candidate,
                                matchedCount: store.matchedCount(for: candidate)
                            ) {
                                store.importRekordboxCandidate(candidate)
                                dismiss()
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 360, height: 320)
        .fileImporter(
            isPresented: $store.showingRekordboxFileImporter,
            allowedContentTypes: [.m3uPlaylist, .m3u8Playlist, .xml, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }
                store.importRekordboxFile(url: url)
            }
        }
    }
}

private struct RekordboxImportRow: View {
    let candidate: PlaylistImportCandidate
    let matchedCount: Int
    let onImport: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onImport) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SetaTheme.text)
                        .lineLimit(1)
                    Text(summary)
                        .font(.system(size: 10))
                        .foregroundStyle(matchedCount > 0 ? SetaTheme.muted : .orange)
                }
                Spacer()
                if matchedCount > 0 {
                    Text("Import")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SetaTheme.accent)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(isHovered ? Color.white.opacity(0.75) : Color.white.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(matchedCount == 0)
        .onHover { isHovered = $0 }
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

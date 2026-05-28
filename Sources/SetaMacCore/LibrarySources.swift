import Foundation

public struct LibraryFolderEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var path: String
    public var label: String?
    public var bookmarkData: Data?

    public init(
        id: String = UUID().uuidString,
        path: String,
        label: String? = nil,
        bookmarkData: Data? = nil
    ) {
        self.id = id
        self.path = path
        self.label = label
        self.bookmarkData = bookmarkData
    }

    public var displayName: String {
        let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty { return trimmed }
        return URL(fileURLWithPath: path).lastPathComponent
    }
}

public enum FolderBookmarkAccess {
    public struct ScopedFolder: Sendable {
        public let url: URL
        private let shouldStopAccessing: Bool

        public var path: String { url.path }

        fileprivate init(url: URL, shouldStopAccessing: Bool) {
            self.url = url
            self.shouldStopAccessing = shouldStopAccessing
        }

        public func stopAccessing() {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    public static func bookmarkData(for url: URL) -> Data? {
        do {
            return try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            return nil
        }
    }

    public static func resolveURL(from bookmarkData: Data) -> URL? {
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            return url
        } catch {
            return nil
        }
    }

    public static func startAccessing(_ entry: LibraryFolderEntry) -> ScopedFolder? {
        if let bookmarkData = entry.bookmarkData,
           let url = resolveURL(from: bookmarkData) {
            let accessed = url.startAccessingSecurityScopedResource()
            return ScopedFolder(url: url, shouldStopAccessing: accessed)
        }
        let path = entry.path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return ScopedFolder(url: URL(fileURLWithPath: path), shouldStopAccessing: false)
    }

    public static func resolvedPath(for entry: LibraryFolderEntry) -> String? {
        guard let folder = startAccessing(entry) else { return nil }
        defer { folder.stopAccessing() }
        return folder.path
    }
}

public enum ExcludedTracksStorage {
    public static let storageKey = "seta-excluded-tracks-v1"

    public static func load(from defaults: UserDefaults = .standard) -> Set<String> {
        guard let data = defaults.data(forKey: storageKey),
              let paths = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(paths)
    }

    public static func save(_ paths: Set<String>, to defaults: UserDefaults = .standard) {
        let sorted = paths.sorted()
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

public enum LibraryScannerArguments {
    public static func build(
        quick: Bool,
        tracksRoots: [String],
        curateRoots: [String],
        excludedPaths: [String]
    ) -> [String] {
        var args: [String] = []
        if quick {
            args.append("--skip-edges")
        }
        for path in tracksRoots {
            args += ["--tracks-root", path]
        }
        for path in curateRoots {
            args += ["--curate-root", path]
        }
        for path in excludedPaths {
            args += ["--exclude-path", path]
        }
        return args
    }
}

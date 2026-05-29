import Foundation

public struct AppSettings: Codable, Equatable {
    public var lastLibraryPath: String?
    public var setaScannerRoot: String?
    public var showSetZoneOverlay: Bool
    public var tracksFolders: [LibraryFolderEntry]
    public var curateFolders: [LibraryFolderEntry]

    public init(
        lastLibraryPath: String? = nil,
        setaScannerRoot: String? = nil,
        showSetZoneOverlay: Bool = true,
        tracksFolders: [LibraryFolderEntry] = [],
        curateFolders: [LibraryFolderEntry] = []
    ) {
        self.lastLibraryPath = lastLibraryPath
        self.setaScannerRoot = setaScannerRoot
        self.showSetZoneOverlay = showSetZoneOverlay
        self.tracksFolders = tracksFolders
        self.curateFolders = curateFolders
    }

    public static let storageKey = "seta-mac-settings-v1"

    public var hasConfiguredFolders: Bool {
        !tracksFolders.isEmpty || !curateFolders.isEmpty
    }

    public func resolvedTracksRootPaths() -> [String] {
        tracksFolders.compactMap { FolderBookmarkAccess.resolvedPath(for: $0) }
    }

    public func resolvedCurateRootPaths() -> [String] {
        curateFolders.compactMap { FolderBookmarkAccess.resolvedPath(for: $0) }
    }

    public func startAccessingTracksRoots() -> [FolderBookmarkAccess.ScopedFolder] {
        tracksFolders.compactMap { FolderBookmarkAccess.startAccessing($0) }
    }

    public func startAccessingCurateRoots() -> [FolderBookmarkAccess.ScopedFolder] {
        curateFolders.compactMap { FolderBookmarkAccess.startAccessing($0) }
    }

    public static func load(from defaults: UserDefaults = .standard) -> AppSettings {
        guard let data = defaults.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    public static func save(_ settings: AppSettings, to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: storageKey)
    }

    public static func defaultLibraryCandidates(
        settings: AppSettings? = nil,
        bundle: Bundle = .main,
        devSiblingSourceFilePath: String? = nil
    ) -> [URL] {
        ScannerPaths.defaultLibraryCandidates(
            settings: settings ?? load(),
            bundle: bundle,
            devSiblingSourceFilePath: devSiblingSourceFilePath
        )
    }
}

public enum LibraryScanner {
    public struct ScanResult: Equatable, Sendable {
        public var exitCode: Int32
        public var output: String

        public init(exitCode: Int32, output: String) {
            self.exitCode = exitCode
            self.output = output
        }
    }

    public static func scanLibrary(
        at scannerRoot: URL,
        tracksRoots: [String] = [],
        curateRoots: [String] = [],
        excludedPaths: [String] = [],
        quick: Bool = true
    ) -> ScanResult {
        let python = scannerRoot.appendingPathComponent(".venv/bin/python")
        let script = scannerRoot.appendingPathComponent("scan_library.py")
        guard FileManager.default.isExecutableFile(atPath: python.path) else {
            return ScanResult(exitCode: 127, output: "Python scanner not found at \(python.path)")
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = python
        process.arguments = [script.path] + LibraryScannerArguments.build(
            quick: quick,
            tracksRoots: tracksRoots,
            curateRoots: curateRoots,
            excludedPaths: excludedPaths
        )
        process.currentDirectoryURL = scannerRoot
        process.standardOutput = pipe
        process.standardError = pipe
        let collector = ScannerOutputCollector()

        do {
            try process.run()
            collector.startReading(pipe.fileHandleForReading)
            process.waitUntilExit()
            collector.waitForOutput()
            let data = collector.output
            let output = String(data: data, encoding: .utf8) ?? ""
            return ScanResult(exitCode: process.terminationStatus, output: output)
        } catch {
            return ScanResult(exitCode: 1, output: error.localizedDescription)
        }
    }
}

private final class ScannerOutputCollector: @unchecked Sendable {
    private var data = Data()
    private let group = DispatchGroup()

    func startReading(_ handle: FileHandle) {
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            self.data = handle.readDataToEndOfFile()
            self.group.leave()
        }
    }

    func waitForOutput() {
        group.wait()
    }

    var output: Data { data }
}

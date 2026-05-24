import Foundation

public struct AppSettings: Codable, Equatable {
    public var lastLibraryPath: String?
    public var setaScannerRoot: String?
    public var showExploreLinks: Bool
    public var showSetZoneOverlay: Bool

    public init(
        lastLibraryPath: String? = nil,
        setaScannerRoot: String? = nil,
        showExploreLinks: Bool = false,
        showSetZoneOverlay: Bool = true
    ) {
        self.lastLibraryPath = lastLibraryPath
        self.setaScannerRoot = setaScannerRoot
        self.showExploreLinks = showExploreLinks
        self.showSetZoneOverlay = showSetZoneOverlay
    }

    public static let storageKey = "seta-mac-settings-v1"

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

    public static func defaultLibraryCandidates(scannerRoot: String?) -> [URL] {
        var candidates: [URL] = []
        if let last = load().lastLibraryPath {
            candidates.append(URL(fileURLWithPath: last))
        }
        if let scannerRoot {
            candidates.append(URL(fileURLWithPath: scannerRoot).appendingPathComponent("library.json"))
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        candidates.append(URL(fileURLWithPath: "\(home)/Music/tracks/tools/seta/library.json"))
        return candidates
    }
}

public enum LibraryScanner {
    public struct ScanResult: Equatable {
        public var exitCode: Int32
        public var output: String

        public init(exitCode: Int32, output: String) {
            self.exitCode = exitCode
            self.output = output
        }
    }

    public static func scanLibrary(at scannerRoot: URL, quick: Bool = true) -> ScanResult {
        let python = scannerRoot.appendingPathComponent(".venv/bin/python")
        let script = scannerRoot.appendingPathComponent("scan_library.py")
        guard FileManager.default.isExecutableFile(atPath: python.path) else {
            return ScanResult(exitCode: 127, output: "Python scanner not found at \(python.path)")
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = python
        process.arguments = [script.path] + (quick ? ["--skip-edges"] : [])
        process.currentDirectoryURL = scannerRoot
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return ScanResult(exitCode: process.terminationStatus, output: output)
        } catch {
            return ScanResult(exitCode: 1, output: error.localizedDescription)
        }
    }
}

public extension SetaLibrary {
    func exploreLinks(for trackID: String, tracksByID: [String: SetaTrack]) -> [(SetaTrack, Double)] {
        edges.compactMap { edge -> (SetaTrack, Double)? in
            if edge.source == trackID, let track = tracksByID[edge.target] {
                return (track, edge.score)
            }
            if edge.target == trackID, let track = tracksByID[edge.source] {
                return (track, edge.score)
            }
            return nil
        }
        .sorted { $0.1 > $1.1 }
    }

    func visibleEdges(trackIDs: Set<String>) -> [SetaEdge] {
        edges.filter { trackIDs.contains($0.source) && trackIDs.contains($0.target) }
    }

    var hasMixEdges: Bool {
        !edges.isEmpty
    }
}

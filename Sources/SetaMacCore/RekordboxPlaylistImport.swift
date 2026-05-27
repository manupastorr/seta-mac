import Foundation

public struct PlaylistImportCandidate: Equatable, Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let paths: [String]

    public init(name: String, paths: [String]) {
        self.name = name
        self.paths = paths
    }
}

public struct PlaylistImportResult: Equatable {
    public let name: String
    public let matchedTrackIds: [String]
    public let skippedCount: Int

    public var matchedCount: Int { matchedTrackIds.count }
    public var totalCount: Int { matchedCount + skippedCount }
}

public enum RekordboxPlaylistImport {
    public static func matchedCounts(
        for candidates: [PlaylistImportCandidate],
        in tracks: [SetaTrack]
    ) -> [Int] {
        let matcher = LibraryTrackMatcher(tracks: tracks)
        return candidates.map { candidate in
            candidate.paths.reduce(into: 0) { count, path in
                if matcher.trackId(for: path) != nil {
                    count += 1
                }
            }
        }
    }

    public static func matchPaths(_ paths: [String], in tracks: [SetaTrack]) -> PlaylistImportResult {
        let matcher = LibraryTrackMatcher(tracks: tracks)
        var matched: [String] = []
        var skipped = 0
        for path in paths {
            if let id = matcher.trackId(for: path) {
                matched.append(id)
            } else {
                skipped += 1
            }
        }
        return PlaylistImportResult(name: "", matchedTrackIds: matched, skippedCount: skipped)
    }

    public static func parseM3U(at url: URL) throws -> PlaylistImportCandidate {
        let text = try String(contentsOf: url, encoding: .utf8)
        let name = url.deletingPathExtension().lastPathComponent
        var paths: [String] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("#") { continue }
            if let path = normalizedPath(trimmed) {
                paths.append(path)
            }
        }
        return PlaylistImportCandidate(name: name, paths: paths)
    }

    public static func parseRekordboxXML(at url: URL) throws -> [PlaylistImportCandidate] {
        let data = try Data(contentsOf: url)
        let delegate = RekordboxXMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            if let error = delegate.parseError {
                throw error
            }
            throw NSError(
                domain: "SetaRekordboxImport",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not parse Rekordbox XML."]
            )
        }
        return delegate.playlists
    }

    public static func normalizedPath(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.lowercased().hasPrefix("file://") {
            if let url = URL(string: trimmed), url.isFileURL {
                return url.path
            }
            let stripped = String(trimmed.dropFirst("file://".count))
            let decoded = stripped.removingPercentEncoding ?? stripped
            if decoded.hasPrefix("localhost") {
                return String(decoded.dropFirst("localhost".count))
            }
            return decoded
        }

        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            return (trimmed as NSString).expandingTildeInPath
        }

        return nil
    }
}

struct LibraryTrackMatcher {
    private let byPath: [String: String]
    private let byStem: [String: [SetaTrack]]

    init(tracks: [SetaTrack]) {
        var pathIndex: [String: String] = [:]
        var stemIndex: [String: [SetaTrack]] = [:]
        for track in tracks {
            let resolved = (track.path as NSString).standardizingPath
            pathIndex[resolved] = track.id
            let stem = URL(fileURLWithPath: track.path).deletingPathExtension().lastPathComponent.lowercased()
            stemIndex[stem, default: []].append(track)
        }
        byPath = pathIndex
        byStem = stemIndex
    }

    func trackId(for rawPath: String) -> String? {
        guard let normalized = RekordboxPlaylistImport.normalizedPath(rawPath) else { return nil }
        let resolved = (normalized as NSString).standardizingPath
        if let id = byPath[resolved] {
            return id
        }

        let stem = URL(fileURLWithPath: resolved).deletingPathExtension().lastPathComponent.lowercased()
        guard let candidates = byStem[stem], !candidates.isEmpty else { return nil }
        if candidates.count == 1 {
            return candidates[0].id
        }

        let ext = URL(fileURLWithPath: resolved).pathExtension.lowercased()
        let extMatches = candidates.filter {
            URL(fileURLWithPath: $0.path).pathExtension.lowercased() == ext
        }
        if extMatches.count == 1 {
            return extMatches[0].id
        }

        if let size = fileSize(at: resolved) {
            let sizeMatches = candidates.filter { fileSize(at: $0.path) == size }
            if sizeMatches.count == 1 {
                return sizeMatches[0].id
            }
        }

        return nil
    }

    private func fileSize(at path: String) -> Int64? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return attrs?[.size] as? Int64
    }
}

private final class RekordboxXMLParserDelegate: NSObject, XMLParserDelegate {
    var playlists: [PlaylistImportCandidate] = []
    var parseError: Error?

    private var collection: [String: String] = [:]
    private var stack: [(name: String, type: String)] = []
    private var currentPlaylistName: String?
    private var currentPlaylistPaths: [String] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName.uppercased() {
        case "TRACK":
            if let location = attributeDict["Location"] ?? attributeDict["location"],
               let path = RekordboxPlaylistImport.normalizedPath(location) {
                let key = attributeDict["TrackID"] ?? attributeDict["TrackId"] ?? attributeDict["Key"]
                if let key {
                    collection[key] = path
                }
            } else if let key = attributeDict["Key"] ?? attributeDict["TrackID"],
                      let path = collection[key] {
                currentPlaylistPaths.append(path)
            }
        case "NODE":
            let type = attributeDict["Type"] ?? attributeDict["type"] ?? ""
            let name = attributeDict["Name"] ?? attributeDict["name"] ?? ""
            stack.append((name: name, type: type))
            if type == "1", !name.isEmpty {
                currentPlaylistName = name
                currentPlaylistPaths = []
            }
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        parseErrorOccurred parseError: Error
    ) {
        self.parseError = parseError
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        switch elementName.uppercased() {
        case "NODE":
            guard let node = stack.popLast() else { return }
            if node.type == "1", let name = currentPlaylistName, name == node.name, !currentPlaylistPaths.isEmpty {
                playlists.append(PlaylistImportCandidate(name: name, paths: currentPlaylistPaths))
            }
            if node.type == "1" {
                currentPlaylistName = nil
                currentPlaylistPaths = []
            }
        default:
            break
        }
    }
}

public enum RekordboxLibraryBridge {
    public struct LoadResult: Equatable, Sendable {
        public let playlists: [PlaylistImportCandidate]
        public let message: String?

        public init(playlists: [PlaylistImportCandidate], message: String? = nil) {
            self.playlists = playlists
            self.message = message
        }
    }

    public static func loadPlaylists(scannerRoot: URL?) -> LoadResult {
        guard let scannerRoot else {
            return LoadResult(playlists: [], message: "Seta scanner path not configured.")
        }

        let candidates = [
            scannerRoot.appendingPathComponent("scripts/rekordbox_playlists.py"),
            scannerRoot.appendingPathComponent("rekordbox_playlists.py"),
        ]
        guard let script = candidates.first(where: { FileManager.default.isReadableFile(atPath: $0.path) }) else {
            return LoadResult(
                playlists: [],
                message: "Rekordbox helper not found. Export an M3U playlist from Rekordbox instead."
            )
        }

        let python = scannerRoot.appendingPathComponent(".venv/bin/python")
        guard FileManager.default.isExecutableFile(atPath: python.path) else {
            return LoadResult(
                playlists: [],
                message: "Python environment not found. Export an M3U playlist from Rekordbox instead."
            )
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = python
        process.arguments = [script.path]
        process.currentDirectoryURL = scannerRoot
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutCollector = ProcessOutputCollector()
        let stderrCollector = ProcessOutputCollector()
        stdoutCollector.startReading(stdoutPipe.fileHandleForReading)
        stderrCollector.startReading(stderrPipe.fileHandleForReading)

        do {
            try process.run()
        } catch {
            stdoutCollector.waitForOutput()
            stderrCollector.waitForOutput()
            return LoadResult(playlists: [], message: error.localizedDescription)
        }

        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            process.waitUntilExit()
            finished.signal()
        }
        guard finished.wait(timeout: .now() + 20) == .success else {
            process.terminate()
            stdoutCollector.waitForOutput()
            stderrCollector.waitForOutput()
            return LoadResult(
                playlists: [],
                message: "Reading Rekordbox timed out. Quit Rekordbox and try again, or export M3U."
            )
        }
        stdoutCollector.waitForOutput()
        stderrCollector.waitForOutput()

        let stdout = stdoutCollector.output
        let stderr = String(data: stderrCollector.output, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0,
              let payload = decodePayload(from: stdout) else {
            if !stderr.isEmpty {
                return LoadResult(playlists: [], message: friendlyProcessMessage(stderr))
            }
            return LoadResult(
                playlists: [],
                message: "Could not read Rekordbox library. Quit Rekordbox and try again, or export M3U."
            )
        }
        let playlists = payload.playlists
            .filter { !$0.paths.isEmpty }
            .map { PlaylistImportCandidate(name: $0.name, paths: $0.paths) }
        if playlists.isEmpty {
            return LoadResult(playlists: [], message: "No Rekordbox playlists with tracks found.")
        }
        return LoadResult(playlists: playlists)
    }

    public static func playlistCount(inProcessOutput data: Data) -> Int? {
        decodePayloadData(from: data)?.playlists.count
    }

    private static func decodePayload(from data: Data) -> RekordboxPayload? {
        decodePayloadData(from: data)
    }

    private static func decodePayloadData(from data: Data) -> RekordboxPayload? {
        if let payload = try? JSONDecoder().decode(RekordboxPayload.self, from: data) {
            return payload
        }
        guard let text = String(data: data, encoding: .utf8),
              let start = text.range(of: "{\"playlists\"")?.lowerBound else {
            return nil
        }
        let json = String(text[start...])
        return try? JSONDecoder().decode(RekordboxPayload.self, from: Data(json.utf8))
    }

    private static func friendlyProcessMessage(_ stderr: String) -> String {
        if stderr.localizedCaseInsensitiveContains("Rekordbox is running") {
            return "Rekordbox is open. Quit Rekordbox and try again, or export M3U."
        }
        if stderr.count > 180 {
            return String(stderr.prefix(180)) + "…"
        }
        return stderr
    }

    private struct RekordboxPayload: Decodable {
        struct Entry: Decodable {
            let name: String
            let paths: [String]
        }

        let playlists: [Entry]
    }
}

private final class ProcessOutputCollector: @unchecked Sendable {
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

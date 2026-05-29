import Foundation

public enum ScannerPaths {
    public static let applicationSupportAppName = "SetaMac"
    public static let scannerDirectoryName = "scanner"
    public static let bundledResourcesDirectoryName = "Scanner"
    public static let scanScriptName = "scan_library.py"
    public static let pythonRelativePath = ".venv/bin/python"

    public static func applicationSupportScannerRoot(
        homeDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) -> URL {
        let home = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(applicationSupportAppName, isDirectory: true)
            .appendingPathComponent(scannerDirectoryName, isDirectory: true)
    }

    public static func legacyDefaultScannerRoot(
        homeDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) -> URL {
        let home = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Music/tracks/tools/seta", isDirectory: true)
    }

    public static func bundledScannerRoot(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) -> URL? {
        guard let resourceURL = bundle.resourceURL else { return nil }
        let root = resourceURL.appendingPathComponent(bundledResourcesDirectoryName, isDirectory: true)
        return isScannerInstalled(at: root, fileManager: fileManager) ? root : nil
    }

    public static func devSiblingScannerRoot(
        sourceFilePath: String,
        fileManager: FileManager = .default
    ) -> URL? {
        let sibling = URL(fileURLWithPath: sourceFilePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("seta", isDirectory: true)
        return isScannerInstalled(at: sibling, fileManager: fileManager) ? sibling : nil
    }

    public static func isScannerInstalled(
        at root: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        fileManager.fileExists(atPath: root.appendingPathComponent(scanScriptName).path)
    }

    public static func isScannerReady(
        at root: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        guard isScannerInstalled(at: root, fileManager: fileManager) else { return false }
        return fileManager.isExecutableFile(atPath: root.appendingPathComponent(pythonRelativePath).path)
    }

    public static func configuredScannerRoot(
        settings: AppSettings,
        fileManager: FileManager = .default
    ) -> URL? {
        guard let path = settings.setaScannerRoot?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        let root = URL(fileURLWithPath: path, isDirectory: true)
        return isScannerInstalled(at: root, fileManager: fileManager) ? root : nil
    }

    public static func preferredScannerRoot(
        settings: AppSettings,
        bundle: Bundle = .main,
        devSiblingSourceFilePath: String? = nil,
        homeDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) -> URL? {
        if let configured = configuredScannerRoot(settings: settings, fileManager: fileManager) {
            return configured
        }

        let appSupport = applicationSupportScannerRoot(homeDirectory: homeDirectory, fileManager: fileManager)
        if isScannerInstalled(at: appSupport, fileManager: fileManager) {
            return appSupport
        }

        if let devSiblingSourceFilePath,
           let sibling = devSiblingScannerRoot(sourceFilePath: devSiblingSourceFilePath, fileManager: fileManager) {
            return sibling
        }

        let legacy = legacyDefaultScannerRoot(homeDirectory: homeDirectory, fileManager: fileManager)
        if isScannerInstalled(at: legacy, fileManager: fileManager) {
            return legacy
        }

        return nil
    }

    public static func libraryJSON(at scannerRoot: URL) -> URL {
        scannerRoot.appendingPathComponent("library.json")
    }

    public static func defaultLibraryCandidates(
        settings: AppSettings,
        bundle: Bundle = .main,
        devSiblingSourceFilePath: String? = nil,
        homeDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) -> [URL] {
        var candidates: [URL] = []
        var seenPaths = Set<String>()

        func appendCandidate(_ url: URL) {
            let path = url.path
            guard seenPaths.insert(path).inserted else { return }
            candidates.append(url)
        }

        if let last = settings.lastLibraryPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !last.isEmpty {
            appendCandidate(URL(fileURLWithPath: last))
        }

        if let root = preferredScannerRoot(
            settings: settings,
            bundle: bundle,
            devSiblingSourceFilePath: devSiblingSourceFilePath,
            homeDirectory: homeDirectory,
            fileManager: fileManager
        ) {
            appendCandidate(libraryJSON(at: root))
        }

        appendCandidate(
            libraryJSON(at: legacyDefaultScannerRoot(homeDirectory: homeDirectory, fileManager: fileManager))
        )
        return candidates
    }
}

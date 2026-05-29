import Foundation

public enum ScannerInstallerPhase: String, Sendable {
    case preparing
    case copyingFiles
    case creatingEnvironment
    case installingDependencies
    case finished
}

public struct ScannerInstallResult: Equatable, Sendable {
    public var success: Bool
    public var scannerRoot: URL?
    public var message: String
    public var output: String

    public init(success: Bool, scannerRoot: URL?, message: String, output: String) {
        self.success = success
        self.scannerRoot = scannerRoot
        self.message = message
        self.output = output
    }
}

public enum ScannerInstaller {
    private static let excludedItemNames: Set<String> = [
        ".venv",
        "library.json",
        "cache.json",
        ".env",
        ".env.example",
        ".gitignore",
        "__pycache__",
        ".git",
        ".DS_Store",
        "AGENTS.md",
        "docs",
        "tests",
    ]

    public static func needsInstall(
        destinationRoot: URL? = nil,
        homeDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) -> Bool {
        let destination = destinationRoot
            ?? ScannerPaths.applicationSupportScannerRoot(homeDirectory: homeDirectory, fileManager: fileManager)
        return !ScannerPaths.isScannerReady(at: destination, fileManager: fileManager)
    }

    public static func install(
        bundledRoot: URL? = nil,
        destinationRoot: URL? = nil,
        python3Executable: URL? = nil,
        homeDirectory: URL? = nil,
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        phaseHandler: ((ScannerInstallerPhase) -> Void)? = nil
    ) -> ScannerInstallResult {
        phaseHandler?(.preparing)

        let destination = destinationRoot
            ?? ScannerPaths.applicationSupportScannerRoot(homeDirectory: homeDirectory, fileManager: fileManager)
        guard let source = bundledRoot ?? ScannerPaths.bundledScannerRoot(bundle: bundle, fileManager: fileManager) else {
            return failure(
                message: "Scanner files were not found inside SetaMac.",
                output: "",
                phaseHandler: phaseHandler
            )
        }

        phaseHandler?(.copyingFiles)
        do {
            try syncScannerFiles(from: source, to: destination, fileManager: fileManager)
        } catch {
            return failure(
                message: "Could not copy scanner files.",
                output: error.localizedDescription,
                phaseHandler: phaseHandler
            )
        }

        let wasReady = fileManager.isExecutableFile(
            atPath: destination.appendingPathComponent(ScannerPaths.pythonRelativePath).path
        )
        let requirements = destination.appendingPathComponent("requirements.txt")
        guard fileManager.isReadableFile(atPath: requirements.path) else {
            return failure(
                message: "Scanner requirements file is missing.",
                output: requirements.path,
                phaseHandler: phaseHandler
            )
        }

        let venvPython = destination.appendingPathComponent(ScannerPaths.pythonRelativePath)
        if !fileManager.isExecutableFile(atPath: venvPython.path) {
            let python3 = resolvePython3(executable: python3Executable, fileManager: fileManager)
            guard let python3 else {
                return failure(
                    message: "Python 3 was not found on this Mac.",
                    output: "Install Xcode Command Line Tools or Python 3, then try again.",
                    phaseHandler: phaseHandler
                )
            }
            phaseHandler?(.creatingEnvironment)
            let venvResult = runProcess(
                executable: python3,
                arguments: ["-m", "venv", destination.appendingPathComponent(".venv").path],
                currentDirectory: destination
            )
            if venvResult.exitCode != 0 {
                return failure(
                    message: "Could not create the scanner environment.",
                    output: trimmedOutput(venvResult.output),
                    phaseHandler: phaseHandler
                )
            }
        }

        guard fileManager.isExecutableFile(atPath: venvPython.path) else {
            return failure(
                message: "Scanner Python environment is unavailable.",
                output: venvPython.path,
                phaseHandler: phaseHandler
            )
        }

        phaseHandler?(.installingDependencies)
        let pip = destination.appendingPathComponent(".venv/bin/pip")
        let pipResult = runProcess(
            executable: pip,
            arguments: ["install", "-r", requirements.path],
            currentDirectory: destination
        )
        if pipResult.exitCode != 0 {
            return failure(
                message: "Could not install scanner dependencies.",
                output: trimmedOutput(pipResult.output),
                phaseHandler: phaseHandler
            )
        }

        guard ScannerPaths.isScannerReady(at: destination, fileManager: fileManager) else {
            return failure(
                message: "Scanner setup did not finish correctly.",
                output: destination.path,
                phaseHandler: phaseHandler
            )
        }

        phaseHandler?(.finished)
        return ScannerInstallResult(
            success: true,
            scannerRoot: destination,
            message: wasReady ? "Scanner updated." : "Scanner installed.",
            output: trimmedOutput(pipResult.output)
        )
    }

    public static func syncScannerFiles(
        from source: URL,
        to destination: URL,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        let items = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for item in items {
            let name = item.lastPathComponent
            if excludedItemNames.contains(name) {
                continue
            }

            let destinationItem = destination.appendingPathComponent(name, isDirectory: false)
            let isDirectory = try item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true

            if isDirectory {
                if fileManager.fileExists(atPath: destinationItem.path) {
                    try syncScannerFiles(from: item, to: destinationItem, fileManager: fileManager)
                } else {
                    try fileManager.copyItem(at: item, to: destinationItem)
                }
                continue
            }

            if fileManager.fileExists(atPath: destinationItem.path) {
                try fileManager.removeItem(at: destinationItem)
            }
            try fileManager.copyItem(at: item, to: destinationItem)
        }
    }

    public static func systemPython3(fileManager: FileManager = .default) -> URL? {
        let candidates = [
            "/usr/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
        ]
        return candidates
            .map { URL(fileURLWithPath: $0) }
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    public static func resolvePython3(
        executable: URL?,
        fileManager: FileManager = .default
    ) -> URL? {
        if let executable {
            return fileManager.isExecutableFile(atPath: executable.path) ? executable : nil
        }
        return systemPython3(fileManager: fileManager)
    }

    private struct ProcessResult {
        var exitCode: Int32
        var output: String
    }

    private static func runProcess(
        executable: URL,
        arguments: [String],
        currentDirectory: URL
    ) -> ProcessResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        process.standardOutput = pipe
        process.standardError = pipe

        let collector = InstallProcessOutputCollector()
        do {
            try process.run()
            collector.startReading(pipe.fileHandleForReading)
            process.waitUntilExit()
            collector.waitForOutput()
            let output = String(data: collector.output, encoding: .utf8) ?? ""
            return ProcessResult(exitCode: process.terminationStatus, output: output)
        } catch {
            collector.waitForOutput()
            return ProcessResult(exitCode: 1, output: error.localizedDescription)
        }
    }

    private static func failure(
        message: String,
        output: String,
        phaseHandler: ((ScannerInstallerPhase) -> Void)?
    ) -> ScannerInstallResult {
        phaseHandler?(.finished)
        return ScannerInstallResult(
            success: false,
            scannerRoot: nil,
            message: message,
            output: trimmedOutput(output)
        )
    }

    private static func trimmedOutput(_ output: String) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 240 else { return trimmed }
        return String(trimmed.prefix(240)) + "…"
    }
}

private final class InstallProcessOutputCollector: @unchecked Sendable {
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

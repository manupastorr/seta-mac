import Foundation

public enum SetaMacDevSupport {
    /// Dev-only path to resolve the repository-local Scanner folder. Release builds return `nil`.
    public static func devRepositorySourceFilePath(from filePath: String) -> String? {
        #if DEBUG
        return filePath
        #else
        return nil
        #endif
    }
}

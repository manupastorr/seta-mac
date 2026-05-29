import Foundation

public enum SetaMacDevSupport {
    /// Dev-only path to resolve the sibling `../seta` scanner. Release builds return `nil`.
    public static func devSiblingSourceFilePath(from filePath: String) -> String? {
        #if DEBUG
        return filePath
        #else
        return nil
        #endif
    }
}

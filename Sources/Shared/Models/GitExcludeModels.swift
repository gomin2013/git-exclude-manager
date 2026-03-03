import Foundation

/// Represents a single ignore pattern in `.git/info/exclude`
public struct GitExcludePattern: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var pattern: String
    public var isEnabled: Bool
    public var comment: String?
    public let createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        pattern: String,
        isEnabled: Bool = true,
        comment: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.pattern = pattern
        self.isEnabled = isEnabled
        self.comment = comment
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Returns the pattern text for display
    public var displayText: String {
        pattern
    }

    /// Returns the full line as it appears in `.git/info/exclude`
    public var lineInFile: String {
        let line = isEnabled ? pattern : "# " + pattern
        if let comment = comment, !comment.isEmpty {
            return line + " # " + comment
        }
        return line
    }

    /// Indicates if this pattern is valid (non-empty)
    public var isValid: Bool {
        !pattern.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// Represents a Git repository with its exclude file
public struct GitRepository: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var path: String
    public var name: String
    public var lastAccessedAt: Date

    public init(
        id: UUID = UUID(),
        path: String,
        name: String = "",
        lastAccessedAt: Date = Date()
    ) {
        self.id = id
        self.path = path
        self.name = name.isEmpty ? (URL(fileURLWithPath: path).lastPathComponent) : name
        self.lastAccessedAt = lastAccessedAt
    }

    /// Returns the path to `.git/info/exclude` file
    public var excludeFilePath: String {
        (path as NSString).appendingPathComponent(".git/info/exclude")
    }

    /// Validates if the given path is a valid Git repository
    public static func isValidRepository(at path: String) -> Bool {
        let gitDirPath = (path as NSString).appendingPathComponent(".git")
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: gitDirPath, isDirectory: &isDir) && isDir.boolValue
    }
}

/// Errors that can occur during helper operations
public enum HelperError: Error, Sendable {
    case fileReadError(String)
    case fileWriteError(String)
    case invalidRepository(String)
    case permissionDenied
    case connectionFailed
    case invalidData(String)
    case unknown(String)

    public var localizedDescription: String {
        switch self {
        case .fileReadError(let msg):
            return NSLocalizedString("error.fileReadError", comment: "") + ": " + msg
        case .fileWriteError(let msg):
            return NSLocalizedString("error.fileWriteError", comment: "") + ": " + msg
        case .invalidRepository(let msg):
            return NSLocalizedString("error.invalidRepository", comment: "") + ": " + msg
        case .permissionDenied:
            return NSLocalizedString("error.permissionDenied", comment: "")
        case .connectionFailed:
            return NSLocalizedString("error.connectionFailed", comment: "")
        case .invalidData(let msg):
            return NSLocalizedString("error.invalidData", comment: "") + ": " + msg
        case .unknown(let msg):
            return NSLocalizedString("error.unknown", comment: "") + ": " + msg
        }
    }
}

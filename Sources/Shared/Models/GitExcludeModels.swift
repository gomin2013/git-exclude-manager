import Foundation

/// One item in `.git/info/exclude`: an ignore pattern, a section break, or verbatim comment lines.
/// Every item can be dragged, so users can group patterns under headings.
public struct GitExcludePattern: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        /// An ignore pattern (`isEnabled` / `comment` apply only here).
        case pattern
        /// A blank line, optionally followed by `# heading`. `pattern` holds the heading ("" = none).
        case section
        /// Comment or unrecognized lines kept verbatim. `pattern` holds the raw text (may contain newlines).
        case comment
    }

    public let id: UUID
    public var pattern: String
    public var kind: Kind
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
        modifiedAt: Date = Date(),
        kind: Kind = .pattern
    ) {
        self.id = id
        self.pattern = pattern
        self.isEnabled = isEnabled
        self.comment = comment
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.kind = kind
    }

    /// Returns the pattern text for display
    public var displayText: String {
        pattern
    }

    /// The comment block `git init` writes. Shown pinned at the top: not deletable, not draggable.
    public static let gitDefaultHeader = """
        # git ls-files --others --exclude-from=.git/info/exclude
        # Lines that start with '#' are comments.
        # For a project mostly in C, the following would be a good set of
        # exclude patterns (uncomment them if you want to use them):
        # *.[oa]
        # *~
        """

    /// Exact match only — once the user edits it, it's an ordinary comment again.
    public var isGitDefaultHeader: Bool {
        kind == .comment && pattern == Self.gitDefaultHeader
    }

    /// The line(s) this item occupies in `.git/info/exclude`.
    public var linesInFile: [String] {
        switch kind {
        case .pattern:
            // Git has no end-of-line comments (`pattern # note` is one pattern), so the comment gets its own `##` line
            // above — `##`, not `#`, so it never reads back as a section heading or a disabled pattern.
            guard let comment, !comment.isEmpty else { return [lineInFile] }
            return ["## " + comment.replacingOccurrences(of: "\n", with: " "), lineInFile]
        case .section: return pattern.isEmpty ? [""] : ["", "# " + pattern]
        case .comment: return pattern.components(separatedBy: "\n")
        }
    }

    /// The pattern's own line in `.git/info/exclude`, without its `##` comment line.
    public var lineInFile: String {
        isEnabled ? pattern : "#" + pattern  // no space: `# text` is read back as a plain comment
    }

    /// Indicates if this pattern is valid (non-empty)
    public var isValid: Bool {
        !pattern.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Returns a localized validation error message, or `nil` if valid.
    public var validationError: String? {
        let trimmed = pattern.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return NSLocalizedString("error.invalidPattern", comment: "")
        }
        if trimmed.count > 250 {
            return NSLocalizedString("error.patternTooLong", comment: "")
        }
        if trimmed.contains("\0") {
            return NSLocalizedString("error.invalidPattern", comment: "")
        }
        return nil
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
    /// `~/Developer/app` instead of `/Users/name/Developer/app` — shorter, and keeps usernames out of screenshots.
    public var displayPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }

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

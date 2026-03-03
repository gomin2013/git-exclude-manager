import Foundation

/// Handles direct read access to `.git/info/exclude`.
public struct ExcludeFileService {
    // MARK: - Public Interface

    public init() { }

    public func readExcludeFile(repoPath: String) throws -> Data {
        guard GitRepository.isValidRepository(at: repoPath) else {
            throw HelperError.invalidRepository(repoPath)
        }

        let excludePath = (repoPath as NSString).appendingPathComponent(".git/info/exclude")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: excludePath) else {
            throw HelperError.fileReadError(excludePath)
        }

        do {
            return try Data(contentsOf: URL(fileURLWithPath: excludePath))
        } catch {
            throw HelperError.fileReadError(error.localizedDescription)
        }
    }

    /// Writes content to `.git/info/exclude` atomically.
    public func writeExcludeFile(repoPath: String, content: String) throws {
        guard GitRepository.isValidRepository(at: repoPath) else {
            throw HelperError.invalidRepository(repoPath)
        }

        try ensureExcludeDirectoryExists(repoPath: repoPath)

        let excludePath = (repoPath as NSString).appendingPathComponent(".git/info/exclude")
        let tempPath = excludePath + ".tmp"
        let fileManager = FileManager.default

        do {
            try content.write(toFile: tempPath, atomically: false, encoding: .utf8)

            if fileManager.fileExists(atPath: excludePath) {
                // ponytail: single rolling backup (exclude.bak), timestamped history if users ask for multi-step undo
                _ = try fileManager.replaceItemAt(
                    URL(fileURLWithPath: excludePath),
                    withItemAt: URL(fileURLWithPath: tempPath),
                    backupItemName: "exclude.bak",
                    options: .withoutDeletingBackupItem
                )
            } else {
                try fileManager.moveItem(atPath: tempPath, toPath: excludePath)
            }
        } catch let helperError as HelperError {
            try? fileManager.removeItem(atPath: tempPath)
            throw helperError
        } catch {
            try? fileManager.removeItem(atPath: tempPath)
            throw HelperError.fileWriteError(error.localizedDescription)
        }
    }

    /// Reverts `.git/info/exclude` to the content before the last write.
    public func restoreBackup(repoPath: String) throws {
        let backupPath = (repoPath as NSString).appendingPathComponent(".git/info/exclude.bak")
        guard FileManager.default.fileExists(atPath: backupPath) else {
            throw HelperError.fileReadError(backupPath)
        }
        let content = try String(contentsOfFile: backupPath, encoding: .utf8)
        try writeExcludeFile(repoPath: repoPath, content: content)
    }

    /// Ensures `.git/info/` directory exists, creating it if necessary.
    public func ensureExcludeDirectoryExists(repoPath: String) throws {
        let infoPath = (repoPath as NSString).appendingPathComponent(".git/info")
        let fileManager = FileManager.default
        var isDir: ObjCBool = false

        if !fileManager.fileExists(atPath: infoPath, isDirectory: &isDir) || !isDir.boolValue {
            do {
                try fileManager.createDirectory(
                    atPath: infoPath,
                    withIntermediateDirectories: true
                )
            } catch {
                throw HelperError.fileWriteError(error.localizedDescription)
            }
        }
    }
}

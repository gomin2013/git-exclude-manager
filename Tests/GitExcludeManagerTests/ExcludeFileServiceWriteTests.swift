import XCTest
@testable import Shared

final class ExcludeFileServiceWriteTests: XCTestCase {

    // MARK: - ensureExcludeDirectoryExists

    func testEnsureDirectoryCreatesIfMissing() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let gitDir = root.appendingPathComponent(".git", isDirectory: true)
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = ExcludeFileService()
        try service.ensureExcludeDirectoryExists(repoPath: root.path)

        var isDir: ObjCBool = false
        let infoPath = root.appendingPathComponent(".git/info").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: infoPath, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    func testEnsureDirectoryDoesNotFailIfAlreadyExists() throws {
        let root = try makeTemporaryRepository(excludeContent: "")
        defer { try? FileManager.default.removeItem(at: root) }

        let service = ExcludeFileService()
        // Should not throw even if directory already exists
        XCTAssertNoThrow(try service.ensureExcludeDirectoryExists(repoPath: root.path))
    }

    // MARK: - writeExcludeFile

    func testWriteCreatesExcludeFile() throws {
        let root = try makeTemporaryRepository(excludeContent: "")
        defer { try? FileManager.default.removeItem(at: root) }

        let service = ExcludeFileService()
        let content = "*.log\nnode_modules/\n"
        try service.writeExcludeFile(repoPath: root.path, content: content)

        let excludePath = root.appendingPathComponent(".git/info/exclude").path
        let written = try String(contentsOfFile: excludePath, encoding: .utf8)
        XCTAssertEqual(written, content)
    }

    func testWriteOverwritesExistingFile() throws {
        let root = try makeTemporaryRepository(excludeContent: "old content\n")
        defer { try? FileManager.default.removeItem(at: root) }

        let service = ExcludeFileService()
        let newContent = "*.log\n"
        try service.writeExcludeFile(repoPath: root.path, content: newContent)

        let excludePath = root.appendingPathComponent(".git/info/exclude").path
        let written = try String(contentsOfFile: excludePath, encoding: .utf8)
        XCTAssertEqual(written, newContent)
    }

    func testWriteThrowsForInvalidRepository() {
        let service = ExcludeFileService()

        XCTAssertThrowsError(
            try service.writeExcludeFile(repoPath: "/tmp/not-a-repo", content: "*.log\n")
        ) { error in
            guard case HelperError.invalidRepository = error else {
                XCTFail("Expected invalidRepository error, got \(error)")
                return
            }
        }
    }

    // MARK: - Backup / Restore

    func testWriteKeepsPreviousContentAsBackup() throws {
        let root = try makeTemporaryRepository(excludeContent: "v1\n")
        defer { try? FileManager.default.removeItem(at: root) }

        let service = ExcludeFileService()
        try service.writeExcludeFile(repoPath: root.path, content: "v2\n")
        try service.writeExcludeFile(repoPath: root.path, content: "v3\n")

        let backupPath = root.appendingPathComponent(".git/info/exclude.bak").path
        XCTAssertEqual(try String(contentsOfFile: backupPath, encoding: .utf8), "v2\n")
    }

    func testRestoreBackupRevertsLastWrite() throws {
        let root = try makeTemporaryRepository(excludeContent: "v1\n")
        defer { try? FileManager.default.removeItem(at: root) }

        let service = ExcludeFileService()
        try service.writeExcludeFile(repoPath: root.path, content: "bad\n")
        try service.restoreBackup(repoPath: root.path)

        let excludePath = root.appendingPathComponent(".git/info/exclude").path
        XCTAssertEqual(try String(contentsOfFile: excludePath, encoding: .utf8), "v1\n")
    }

    func testRestoreBackupThrowsWhenNoBackup() throws {
        let root = try makeTemporaryRepository(excludeContent: "v1\n")
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(try ExcludeFileService().restoreBackup(repoPath: root.path))
    }

    // MARK: - Helpers

    private func makeTemporaryRepository(excludeContent: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let gitInfoDirectory = root.appendingPathComponent(".git/info", isDirectory: true)
        let excludeFile = gitInfoDirectory.appendingPathComponent("exclude")

        try FileManager.default.createDirectory(at: gitInfoDirectory, withIntermediateDirectories: true)

        if !excludeContent.isEmpty {
            guard let data = excludeContent.data(using: .utf8) else {
                throw HelperError.invalidData("Unable to encode test content")
            }
            try data.write(to: excludeFile)
        }

        return root
    }
}


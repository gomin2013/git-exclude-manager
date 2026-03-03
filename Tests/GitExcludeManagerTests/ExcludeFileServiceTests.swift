import XCTest
@testable import Shared

final class ExcludeFileServiceTests: XCTestCase {
    func testReadExcludeFileReturnsDataForValidRepository() throws {
        let temporaryDirectory = try makeTemporaryRepository(
            excludeContent: "*.log\nnode_modules/\n"
        )
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let service = ExcludeFileService()
        let data = try service.readExcludeFile(repoPath: temporaryDirectory.path)
        let content = String(data: data, encoding: .utf8)

        XCTAssertEqual(content, "*.log\nnode_modules/\n")
    }

    func testReadExcludeFileThrowsForInvalidRepository() {
        let service = ExcludeFileService()

        XCTAssertThrowsError(try service.readExcludeFile(repoPath: "/tmp/not-a-repository")) { error in
            guard case HelperError.invalidRepository = error else {
                XCTFail("Expected invalidRepository error")
                return
            }
        }
    }

    private func makeTemporaryRepository(excludeContent: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let gitInfoDirectory = root.appendingPathComponent(".git/info", isDirectory: true)
        let excludeFile = gitInfoDirectory.appendingPathComponent("exclude", isDirectory: false)

        try FileManager.default.createDirectory(
            at: gitInfoDirectory,
            withIntermediateDirectories: true
        )

        guard let data = excludeContent.data(using: .utf8) else {
            throw HelperError.invalidData("Unable to encode test content")
        }
        try data.write(to: excludeFile)

        return root
    }
}

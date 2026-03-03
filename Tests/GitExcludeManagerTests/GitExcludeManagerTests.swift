import XCTest
@testable import Shared
import Foundation

class GitExcludeManagerTests: XCTestCase {

    func testGitExcludePatternCreation() {
        let pattern = GitExcludePattern(
            pattern: "*.log",
            isEnabled: true,
            comment: "Log files"
        )

        XCTAssertEqual(pattern.pattern, "*.log")
        XCTAssertTrue(pattern.isEnabled)
        XCTAssertEqual(pattern.comment, "Log files")
        XCTAssertTrue(pattern.isValid)
    }

    func testGitExcludePatternLineFormat() {
        let pattern = GitExcludePattern(
            pattern: "node_modules/",
            isEnabled: true,
            comment: "Dependencies"
        )

        let expectedLine = "node_modules/ # Dependencies"
        XCTAssertEqual(pattern.lineInFile, expectedLine)
    }

    func testGitExcludePatternDisabledFormat() {
        var pattern = GitExcludePattern(
            pattern: "build/",
            isEnabled: true,
            comment: nil
        )

        pattern.isEnabled = false
        let expectedLine = "#build/"
        XCTAssertEqual(pattern.lineInFile, expectedLine)
    }

    func testGitRepositoryCreation() {
        let repo = GitRepository(
            path: "/Users/test/Projects/MyApp",
            name: "MyApp"
        )

        XCTAssertEqual(repo.path, "/Users/test/Projects/MyApp")
        XCTAssertEqual(repo.name, "MyApp")
    }

    func testGitRepositoryExcludeFilePath() {
        let repo = GitRepository(
            path: "/Users/test/Projects/MyApp",
            name: "MyApp"
        )

        let expectedPath = "/Users/test/Projects/MyApp/.git/info/exclude"
        XCTAssertEqual(repo.excludeFilePath, expectedPath)
    }

    func testHelperErrorLocalization() {
        let error = HelperError.invalidRepository("Not a git repo")
        let localizedMsg = error.localizedDescription
        // Verify it contains the error message
        XCTAssertTrue(localizedMsg.contains("Not a git repo"))
    }
}

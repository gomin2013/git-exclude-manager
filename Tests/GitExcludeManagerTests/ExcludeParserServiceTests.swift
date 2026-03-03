import XCTest
@testable import Shared

final class ExcludeParserServiceTests: XCTestCase {
    func testParseContentParsesEnabledDisabledAndComment() {
        let content = """
        *.log
        #build/ # Disabled for now
        # just a comment line
        .DS_Store
        """

        let patterns = ExcludeParserService.parse(content: content)

        XCTAssertEqual(patterns.count, 3)
        XCTAssertEqual(patterns[0].pattern, "*.log")
        XCTAssertTrue(patterns[0].isEnabled)

        XCTAssertEqual(patterns[1].pattern, "build/")
        XCTAssertFalse(patterns[1].isEnabled)
        XCTAssertEqual(patterns[1].comment, "Disabled for now")

        XCTAssertEqual(patterns[2].pattern, ".DS_Store")
        XCTAssertTrue(patterns[2].isEnabled)
    }

    func testParseDataThrowsForInvalidEncoding() {
        let bytes: [UInt8] = [0xFF, 0xFE, 0x00]
        let data = Data(bytes)

        XCTAssertThrowsError(try ExcludeParserService.parseItems(data: data)) { error in
            guard case HelperError.invalidData = error else {
                XCTFail("Expected invalidData error")
                return
            }
        }
    }

    func testGitDefaultHeaderIsAllComments() {
        // Exactly what `git init` writes to .git/info/exclude
        let content = """
        # git ls-files --others --exclude-from=.git/info/exclude
        # Lines that start with '#' are comments.
        # For a project mostly in C, the following would be a good set of
        # exclude patterns (uncomment them if you want to use them):
        # *.[oa]
        # *~
        """

        XCTAssertTrue(ExcludeParserService.parse(content: content).isEmpty)
    }

    func testDisabledPatternRoundTrips() {
        let original = [
            GitExcludePattern(pattern: "build/", isEnabled: false, comment: "later"),
            GitExcludePattern(pattern: "*.log", isEnabled: true, comment: nil)
        ]

        let reparsed = ExcludeParserService.parse(content: ExcludeParserService.serialize(original))

        XCTAssertEqual(reparsed.map(\.pattern), ["build/", "*.log"])
        XCTAssertEqual(reparsed.map(\.isEnabled), [false, true])
        XCTAssertEqual(reparsed.first?.comment, "later")
    }
}

import XCTest
@testable import Shared

final class GitExcludePatternValidationTests: XCTestCase {

    func testValidPatternHasNoError() {
        let pattern = GitExcludePattern(pattern: "*.log", isEnabled: true)
        XCTAssertNil(pattern.validationError)
    }

    func testEmptyPatternReturnsError() {
        let pattern = GitExcludePattern(pattern: "", isEnabled: true)
        XCTAssertNotNil(pattern.validationError)
    }

    func testWhitespaceOnlyPatternReturnsError() {
        let pattern = GitExcludePattern(pattern: "   ", isEnabled: true)
        XCTAssertNotNil(pattern.validationError)
    }

    func testPatternExceeding250CharsReturnsError() {
        let longPattern = String(repeating: "a", count: 251)
        let pattern = GitExcludePattern(pattern: longPattern, isEnabled: true)
        XCTAssertNotNil(pattern.validationError)
    }

    func testPatternOf250CharsIsValid() {
        let exactPattern = String(repeating: "a", count: 250)
        let pattern = GitExcludePattern(pattern: exactPattern, isEnabled: true)
        XCTAssertNil(pattern.validationError)
    }

    func testPatternWithNullByteReturnsError() {
        let pattern = GitExcludePattern(pattern: "*.log\0", isEnabled: true)
        XCTAssertNotNil(pattern.validationError)
    }

    func testPatternWithCommentIsValid() {
        let pattern = GitExcludePattern(pattern: "node_modules/", isEnabled: true, comment: "NPM deps")
        XCTAssertNil(pattern.validationError)
    }
}


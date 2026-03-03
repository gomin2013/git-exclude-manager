import XCTest
import Shared
@testable import GitExcludeManagerApp

@MainActor
final class EditorViewModelTests: XCTestCase {
    func testNewPatternStartsEmptyAndInvalid() {
        let viewModel = EditorViewModel()

        XCTAssertFalse(viewModel.isEditing)
        XCTAssertFalse(viewModel.isValid)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.createPattern())
        XCTAssertNotNil(viewModel.validationError)
    }

    func testEditingKeepsIdAndTrimsPattern() {
        let original = GitExcludePattern(pattern: "*.log", comment: "Logs")
        let viewModel = EditorViewModel(pattern: original)
        XCTAssertTrue(viewModel.isEditing)
        XCTAssertEqual(viewModel.commentText, "Logs")

        viewModel.patternText = "  *.tmp  "
        viewModel.commentText = ""
        let created = viewModel.createPattern()

        XCTAssertEqual(created?.id, original.id)
        XCTAssertEqual(created?.pattern, "*.tmp")
        XCTAssertNil(created?.comment)
        XCTAssertNil(viewModel.validationError)
    }

    func testTooLongPatternIsRejected() {
        let viewModel = EditorViewModel()
        viewModel.patternText = String(repeating: "a", count: 251)

        XCTAssertNil(viewModel.createPattern())
        XCTAssertNotNil(viewModel.validationError)
    }

    func testResetClearsEverything() {
        let viewModel = EditorViewModel(pattern: GitExcludePattern(pattern: "x"))
        viewModel.reset()

        XCTAssertEqual(viewModel.patternText, "")
        XCTAssertEqual(viewModel.commentText, "")
        XCTAssertFalse(viewModel.isEditing)
    }
}

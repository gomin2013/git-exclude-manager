import XCTest
import Shared
@testable import GitExcludeManagerApp

/// No repository is selected, so saves never reach XPC.
@MainActor
final class PatternClipboardTests: XCTestCase {
    func testCopyKeepsFileOrderSkipsSectionsAndRemembersSource() {
        let viewModel = PatternsViewModel()
        viewModel.patterns = ExcludeParserService.parseItems(content: "\n# Logs\n*.log\n.env # secrets\n")
        let ids = Set(viewModel.patterns.map(\.id))   // section + both patterns selected

        viewModel.copyToClipboard(ids, from: "web-app")

        XCTAssertEqual(viewModel.clipboard.map(\.pattern.pattern), ["*.log", ".env"])
        XCTAssertEqual(viewModel.clipboard.map(\.repo), ["web-app", "web-app"])
        XCTAssertEqual(viewModel.clipboard[1].pattern.comment, "secrets")
    }

    func testCopyAccumulatesAcrossReposWithoutDuplicates() {
        let viewModel = PatternsViewModel()
        viewModel.patterns = ExcludeParserService.parseItems(content: "*.log\n")
        viewModel.copyToClipboard(Set(viewModel.patterns.map(\.id)), from: "web-app")
        viewModel.patterns = ExcludeParserService.parseItems(content: "*.log\ncoverage/\n")
        viewModel.copyToClipboard(Set(viewModel.patterns.map(\.id)), from: "api")

        XCTAssertEqual(viewModel.clipboard.map(\.pattern.pattern), ["*.log", "coverage/"])
        XCTAssertEqual(viewModel.clipboard.map(\.repo), ["web-app", "api"])   // first source wins
    }

    func testPasteAddsOnlyMissingPatternsWithFreshIDs() {
        let viewModel = PatternsViewModel()
        viewModel.patterns = ExcludeParserService.parseItems(content: "*.log\ncoverage/\n")
        viewModel.copyToClipboard(Set(viewModel.patterns.map(\.id)), from: "api")
        viewModel.patterns = ExcludeParserService.parseItems(content: "*.log\n")

        let added = viewModel.paste(viewModel.clipboard)

        XCTAssertEqual(added, 1)
        XCTAssertEqual(viewModel.patterns.map(\.pattern), ["*.log", "coverage/"])
        XCTAssertNotEqual(viewModel.patterns[1].id, viewModel.clipboard[1].pattern.id)
    }

    func testPasteTextParsesLinesFromSystemPasteboard() {
        let viewModel = PatternsViewModel()
        viewModel.patterns = ExcludeParserService.parseItems(content: ".DS_Store\n")

        let added = viewModel.pasteText("# from .gitignore\n.DS_Store\nnode_modules/\n\n*.tmp\n")

        XCTAssertEqual(added, 2)
        XCTAssertEqual(viewModel.patterns.map(\.pattern), [".DS_Store", "node_modules/", "*.tmp"])
    }

    func testRemoveAndClear() {
        let viewModel = PatternsViewModel()
        viewModel.patterns = ExcludeParserService.parseItems(content: "a\nb\n")
        viewModel.copyToClipboard(Set(viewModel.patterns.map(\.id)), from: "x")

        viewModel.removeFromClipboard(viewModel.clipboard[0].id)
        XCTAssertEqual(viewModel.clipboard.map(\.pattern.pattern), ["b"])
        viewModel.clearClipboard()
        XCTAssertTrue(viewModel.clipboard.isEmpty)
    }
}

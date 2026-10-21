import XCTest
import Shared
@testable import GitExcludeManagerApp

/// No repository is selected, so these never reach XPC.
@MainActor
final class PatternsViewModelEditTests: XCTestCase {
    func testEditKeepsEnabledStateAndLeadingComments() {
        let viewModel = PatternsViewModel()
        let original = GitExcludePattern(pattern: "build/", isEnabled: false, comment: nil)
        viewModel.patterns = [original]

        // EditorViewModel always produces isEnabled: true
        viewModel.editPattern(GitExcludePattern(id: original.id, pattern: "dist/", comment: "renamed"))

        let edited = viewModel.patterns[0]
        XCTAssertEqual(edited.pattern, "dist/")
        XCTAssertEqual(edited.comment, "renamed")
        XCTAssertFalse(edited.isEnabled)
        XCTAssertEqual(edited.createdAt, original.createdAt)
    }

    func testFirstPatternInCommentOnlyFileGoesBelowExistingComments() {
        let viewModel = PatternsViewModel()
        viewModel.patterns = ExcludeParserService.parseItems(content: "# git ls-files ...\n# *~\n")

        viewModel.addPattern(GitExcludePattern(pattern: ".env"))

        XCTAssertEqual(ExcludeParserService.serialize(viewModel.patterns), "# git ls-files ...\n# *~\n.env\n")
    }

    // MARK: - Sections

    func testAddAndRenameSection() {
        let viewModel = PatternsViewModel()
        viewModel.patterns = [GitExcludePattern(pattern: "a")]

        viewModel.addSection()
        let section = viewModel.patterns[1]
        viewModel.renameSection(section.id, to: "  Tools  ")

        XCTAssertEqual(ExcludeParserService.serialize(viewModel.patterns), "a\n\n# Tools\n")
    }

    /// A new section opens its heading for typing — List(selection:) never focuses an always-visible TextField.
    func testNewSectionStartsEditingItsHeading() {
        let viewModel = PatternsViewModel()

        viewModel.addSection()

        XCTAssertEqual(viewModel.editingSectionID, viewModel.patterns.last?.id)
    }

    func testCountsAndSearchOnlyConsiderPatterns() {
        let viewModel = PatternsViewModel()
        viewModel.patterns = ExcludeParserService.parseItems(content: "# header\n\n# Logs\n*.log\n#tmp/\n")

        XCTAssertEqual(viewModel.patternCount, 2)
        XCTAssertEqual(viewModel.enabledCount, 1)
        viewModel.searchText = "log"
        XCTAssertEqual(viewModel.filteredPatterns.map(\.pattern), ["*.log"])
    }

    // MARK: - Import

    func testMergeImportAddsOnlyNewPatternsAndKeepsExisting() {
        let viewModel = PatternsViewModel()
        viewModel.patterns = [GitExcludePattern(pattern: "*.log", isEnabled: false, comment: "mine")]

        viewModel.applyImport(
            [GitExcludePattern(pattern: "*.log", isEnabled: true),
             GitExcludePattern(pattern: "", kind: .section),
             GitExcludePattern(pattern: ".env")],
            replace: false
        )

        XCTAssertEqual(viewModel.patterns.map(\.pattern), ["*.log", ".env"])
        XCTAssertFalse(viewModel.patterns[0].isEnabled)
        XCTAssertEqual(viewModel.patterns[0].comment, "mine")
    }

    func testReplaceImportSwapsAllPatterns() {
        let viewModel = PatternsViewModel()
        viewModel.patterns = [GitExcludePattern(pattern: "*.log")]

        viewModel.applyImport([GitExcludePattern(pattern: ".env")], replace: true)

        XCTAssertEqual(viewModel.patterns.map(\.pattern), [".env"])
    }

    // MARK: - Reorder

    func testSectionsCanBeDraggedLikePatterns() {
        let viewModel = PatternsViewModel()
        viewModel.patterns = [
            GitExcludePattern(pattern: "a"),
            GitExcludePattern(pattern: "b"),
            GitExcludePattern(pattern: "Tools", kind: .section)
        ]

        viewModel.movePatterns(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.patterns.map(\.pattern), ["Tools", "a", "b"])
        XCTAssertEqual(viewModel.patterns[0].kind, .section)
    }

    // MARK: - git's default header is pinned

    private let gitHeader = """
    # git ls-files --others --exclude-from=.git/info/exclude
    # Lines that start with '#' are comments.
    # For a project mostly in C, the following would be a good set of
    # exclude patterns (uncomment them if you want to use them):
    # *.[oa]
    # *~

    """

    func testGitDefaultHeaderIsRecognizedOnlyWhenUnchanged() {
        XCTAssertTrue(ExcludeParserService.parseItems(content: gitHeader)[0].isGitDefaultHeader)
        let edited = gitHeader.replacingOccurrences(of: "# *~", with: "# *~ (mine)")
        XCTAssertFalse(ExcludeParserService.parseItems(content: edited)[0].isGitDefaultHeader)
    }

    func testNothingCanBeMovedAboveOrInPlaceOfGitHeader() {
        let viewModel = PatternsViewModel()
        viewModel.patterns = ExcludeParserService.parseItems(content: gitHeader + "a\nb\n")

        viewModel.movePatterns(from: IndexSet(integer: 2), to: 0)   // b above the header
        XCTAssertTrue(viewModel.patterns[0].isGitDefaultHeader)
        XCTAssertEqual(viewModel.patterns.map(\.pattern).dropFirst(), ["b", "a"])

        viewModel.movePatterns(from: IndexSet(integer: 0), to: 3)   // header itself
        XCTAssertTrue(viewModel.patterns[0].isGitDefaultHeader)
    }

    // MARK: - Pattern suggestions from other repositories

    func testSuggestionsExcludeExistingDisabledAndNonPatternItems() {
        let current = ExcludeParserService.parseItems(content: ".DS_Store\n")
        let others = [
            "web-app": ExcludeParserService.parseItems(content: ".DS_Store\n.idea/ # JetBrains\n\n# Tools\n#off/\n"),
            "api-server": ExcludeParserService.parseItems(content: ".idea/\n.env\n.idea/\n")
        ]

        let suggestions = PatternsViewModel.suggestions(current: current, others: others)

        // shared by more repos first, then alphabetical; duplicates within a repo counted once
        XCTAssertEqual(suggestions.map(\.pattern), [".idea/", ".env"])
        XCTAssertEqual(suggestions[0].repos, ["api-server", "web-app"])
        XCTAssertEqual(suggestions[1].repos, ["api-server"])
    }

    func testAddingASuggestionRemovesIt() {
        let viewModel = PatternsViewModel()
        viewModel.suggestionSources = ["other": [GitExcludePattern(pattern: ".env", comment: "secrets")]]
        XCTAssertEqual(viewModel.suggestions.map(\.pattern), [".env"])

        viewModel.addSuggestion(viewModel.suggestions[0])

        XCTAssertEqual(viewModel.patterns.last?.comment, "secrets")
        XCTAssertTrue(viewModel.suggestions.isEmpty)
    }
}

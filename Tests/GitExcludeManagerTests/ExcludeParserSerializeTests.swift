import XCTest
@testable import Shared

final class ExcludeParserSerializeTests: XCTestCase {

    // MARK: - Serialize

    func testSerializeEmptyProducesEmptyFile() {
        XCTAssertEqual(ExcludeParserService.serialize([]), "")
    }

    func testSerializeEnabledPattern() {
        let patterns = [GitExcludePattern(pattern: "*.log", isEnabled: true)]
        let output = ExcludeParserService.serialize(patterns)
        XCTAssertTrue(output.contains("*.log"))
        XCTAssertFalse(output.contains("# *.log"))
    }

    func testSerializeDisabledPattern() {
        let patterns = [GitExcludePattern(pattern: "build/", isEnabled: false)]
        let output = ExcludeParserService.serialize(patterns)
        // Disabled patterns are commented out
        XCTAssertEqual(output, "#build/\n")
    }

    func testSerializePatternWithComment() {
        let patterns = [GitExcludePattern(pattern: "*.log", isEnabled: true, comment: "Log files")]
        let output = ExcludeParserService.serialize(patterns)
        XCTAssertTrue(output.contains("*.log # Log files"))
    }

    func testSerializeTrailingNewline() {
        let patterns = [GitExcludePattern(pattern: "*.log", isEnabled: true)]
        let output = ExcludeParserService.serialize(patterns)
        XCTAssertTrue(output.hasSuffix("\n"))
    }

    // MARK: - Roundtrip

    func testRoundtripEnabledPattern() {
        let original = [
            GitExcludePattern(pattern: "*.log", isEnabled: true, comment: "Log files"),
            GitExcludePattern(pattern: "node_modules/", isEnabled: true)
        ]
        let serialized = ExcludeParserService.serialize(original)
        let recovered = ExcludeParserService.parse(content: serialized)

        XCTAssertEqual(original.map(\.pattern), recovered.map(\.pattern))
        XCTAssertEqual(original.map(\.isEnabled), recovered.map(\.isEnabled))
        XCTAssertEqual(original.map(\.comment), recovered.map(\.comment))
    }

    func testRoundtripDisabledPattern() {
        let original = [
            GitExcludePattern(pattern: "build/", isEnabled: false, comment: "Build output")
        ]
        let serialized = ExcludeParserService.serialize(original)
        let recovered = ExcludeParserService.parse(content: serialized)

        XCTAssertEqual(recovered.count, 1)
        XCTAssertEqual(recovered[0].pattern, "build/")
        XCTAssertFalse(recovered[0].isEnabled)
        XCTAssertEqual(recovered[0].comment, "Build output")
    }

    func testRoundtripMixedPatterns() {
        let original = [
            GitExcludePattern(pattern: "*.log", isEnabled: true, comment: "Log files"),
            GitExcludePattern(pattern: "build/", isEnabled: false),
            GitExcludePattern(pattern: ".DS_Store", isEnabled: true)
        ]
        let serialized = ExcludeParserService.serialize(original)
        let recovered = ExcludeParserService.parse(content: serialized)

        XCTAssertEqual(original.count, recovered.count)
        XCTAssertEqual(original.map(\.pattern), recovered.map(\.pattern))
        XCTAssertEqual(original.map(\.isEnabled), recovered.map(\.isEnabled))
    }

    // MARK: - Items: sections, comments, patterns

    func testParsesSectionsCommentsAndPatternsAndRoundtripsExactly() {
        let content = """
        # git ls-files --others --exclude-from=.git/info/exclude
        # Lines that start with '#' are comments.
        # *~

        .DS_Store
        .idea/

        AGENTS.local.md # app notes

        # claude-code-runtime
        **/.claude/worktrees/
        not a pattern
        \u{20}\u{20}\u{20}
        #tmp/

        """

        let items = ExcludeParserService.parseItems(content: content)

        XCTAssertEqual(items.map(\.kind), [
            .comment, .section, .pattern, .pattern, .section, .pattern,
            .section, .pattern, .comment, .pattern
        ])
        XCTAssertEqual(items[0].pattern, """
        # git ls-files --others --exclude-from=.git/info/exclude
        # Lines that start with '#' are comments.
        # *~
        """)
        XCTAssertEqual(items[1].pattern, "")                        // untitled section
        XCTAssertEqual(items[6].pattern, "claude-code-runtime")     // titled section
        XCTAssertEqual(items[8].pattern, "not a pattern\n   ")      // unknown lines kept verbatim
        XCTAssertFalse(items[9].isEnabled)
        XCTAssertEqual(ExcludeParserService.serialize(items), content)
    }

    func testSectionTitleOnlyTakesFirstCommentLine() {
        let items = ExcludeParserService.parseItems(content: "a\n\n# Title\n# details\nb\n")

        XCTAssertEqual(items.map(\.kind), [.pattern, .section, .comment, .pattern])
        XCTAssertEqual(items[1].pattern, "Title")
        XCTAssertEqual(items[2].pattern, "# details")
    }

    func testSectionSerializesAsBlankLinePlusOptionalHeading() {
        XCTAssertEqual(GitExcludePattern(pattern: "", kind: .section).linesInFile, [""])
        XCTAssertEqual(GitExcludePattern(pattern: "Tools", kind: .section).linesInFile, ["", "# Tools"])
    }

    func testCommentOnlyFileRoundtripsUnchanged() {
        let content = "# git ls-files --others --exclude-from=.git/info/exclude\n# *~\n"

        XCTAssertEqual(ExcludeParserService.serialize(ExcludeParserService.parseItems(content: content)), content)
    }
}

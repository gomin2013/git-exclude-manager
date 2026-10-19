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
        XCTAssertTrue(output.contains("## Log files\n*.log\n"))
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

        ## app notes
        AGENTS.local.md

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

    // MARK: - Pattern comments: `## text` above the pattern

    /// The bug this format fixes: git read `AGENTS.local.md # notes` as one pattern. Ask real git about what we write.
    func testCommentedPatternsAreIgnoredByRealGit() throws {
        let repo = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: repo) }
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        XCTAssertEqual(try git(["init", "-q"], in: repo), 0)
        let items = [
            GitExcludePattern(pattern: "AGENTS.local.md", comment: "Local agent configuration files"),
            GitExcludePattern(pattern: "notes.txt", isEnabled: false, comment: "off for now")
        ]
        try ExcludeParserService.serialize(items)
            .write(to: repo.appendingPathComponent(".git/info/exclude"), atomically: true, encoding: .utf8)

        XCTAssertEqual(try git(["check-ignore", "-q", "AGENTS.local.md"], in: repo), 0, "ignored")
        XCTAssertEqual(try git(["check-ignore", "-q", "notes.txt"], in: repo), 1, "disabled → not ignored")
    }

    func testV1InlineCommentsAreDetectedAndRewritten() {
        let v1 = "AGENTS.local.md # Local agent configuration files\nCLAUDE.local.md\n"
        let items = ExcludeParserService.parseItems(content: v1)
        let rewritten = ExcludeParserService.serialize(items)

        XCTAssertTrue(ExcludeParserService.hasInlineComments(content: v1))
        XCTAssertEqual(items.first?.comment, "Local agent configuration files")
        XCTAssertEqual(rewritten, "## Local agent configuration files\nAGENTS.local.md\nCLAUDE.local.md\n")
        XCTAssertFalse(ExcludeParserService.hasInlineComments(content: rewritten), "nothing left to repair")
        XCTAssertFalse(ExcludeParserService.hasInlineComments(content: "*.log\n# plain comment\n"))
    }

    func testDoubleHashLineIsACommentOnlyForThePatternRightBelow() {
        // content → (kinds, comment on the last item)
        let cases: [String: ([GitExcludePattern.Kind], String?)] = [
            "\n## note\n*.log\n": ([.section, .pattern], "note"),               // untitled section, then the pattern
            "\n# Logs\n## note\n#*.tmp\n": ([.section, .pattern], "note"),     // heading stays a heading
            "## orphan\n\n*.log\n": ([.comment, .section, .pattern], nil),      // nothing below → plain comment
            "##foo\n": ([.comment], nil)                                        // never a disabled pattern "#foo"
        ]
        for (content, (kinds, comment)) in cases {
            let items = ExcludeParserService.parseItems(content: content)
            XCTAssertEqual(items.map(\.kind), kinds, content)
            XCTAssertEqual(items.last?.comment, comment, content)
            XCTAssertEqual(ExcludeParserService.serialize(items), content, "round trip: \(content)")
        }
    }

    private func git(_ arguments: [String], in directory: URL) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

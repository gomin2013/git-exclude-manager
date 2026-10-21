import XCTest
import Shared
@testable import GitExcludeManagerApp

/// `-demo`: sample repositories live in memory — edits survive tab switches, nothing goes through the helper.
@MainActor
final class DemoModeTests: XCTestCase {
    func testEditsStayInMemoryAcrossTabs() throws {
        let web = try XCTUnwrap(DemoData.repositories.first), api = DemoData.repositories[1]
        let viewModel = PatternsViewModel(demoFiles: DemoData.files)

        viewModel.loadPatterns(from: web)
        XCTAssertTrue(viewModel.patterns.contains { $0.pattern == ".env.local" })
        viewModel.addPattern(GitExcludePattern(pattern: "*.log"))

        viewModel.loadPatterns(from: api)
        XCTAssertFalse(viewModel.patterns.contains { $0.pattern == "*.log" })
        viewModel.loadPatterns(from: web)
        XCTAssertTrue(viewModel.patterns.contains { $0.pattern == "*.log" })
        XCTAssertEqual(viewModel.history.states.count, 2)  // came back to acme-web's history
        XCTAssertNil(viewModel.errorMessage)               // no helper round-trip to fail
    }

    func testDemoTabsSkipTheGitCheckAndRealSettings() {
        let repositories = RepositoryViewModel(demo: DemoData.repositories)
        repositories.switchTo(DemoData.repositories[2])
        XCTAssertEqual(repositories.selectedRepository?.name, "dotfiles")
        XCTAssertNil(repositories.errorMessage)
        XCTAssertNil(UserDefaults.standard.stringArray(forKey: "app.openTabs")?.first { $0.hasSuffix("/dotfiles") })
    }
}

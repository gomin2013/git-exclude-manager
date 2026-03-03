import XCTest
@testable import GitExcludeManagerApp

@MainActor
final class RepositoryTabsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var roots: [URL] = []

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "RepositoryTabsTests-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        roots.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    func testOpeningReposAddsTabsWithoutDuplicates() throws {
        let viewModel = RepositoryViewModel(defaults: defaults)
        let repoA = try makeRepo(), repoB = try makeRepo()

        viewModel.selectRepository(url: repoA)
        viewModel.selectRepository(url: repoB)
        viewModel.selectRepository(url: repoA)

        XCTAssertEqual(viewModel.openRepositories.map(\.path), [repoA.path, repoB.path])
        XCTAssertEqual(viewModel.selectedRepository?.path, repoA.path)
    }

    func testClosingActiveTabSelectsFirstRemaining() throws {
        let viewModel = RepositoryViewModel(defaults: defaults)
        let repoA = try makeRepo(), repoB = try makeRepo()
        viewModel.selectRepository(url: repoA)
        viewModel.selectRepository(url: repoB)

        viewModel.closeRepository(path: repoB.path)

        XCTAssertEqual(viewModel.openRepositories.map(\.path), [repoA.path])
        XCTAssertEqual(viewModel.selectedRepository?.path, repoA.path)
    }

    func testLastTabCannotBeClosed() throws {
        let viewModel = RepositoryViewModel(defaults: defaults)
        let repoA = try makeRepo()
        viewModel.selectRepository(url: repoA)

        viewModel.closeRepository(path: repoA.path)

        XCTAssertEqual(viewModel.openRepositories.count, 1)
    }

    func testRelaunchRestoresTabsOrderAndSelection() throws {
        let repoA = try makeRepo(), repoB = try makeRepo(), repoC = try makeRepo()
        let first = RepositoryViewModel(defaults: defaults)
        [repoA, repoB, repoC].forEach { first.selectRepository(url: $0) }
        first.moveRepository(path: repoC.path, onto: repoA.path)
        first.switchTo(first.openRepositories[1])                        // select A
        first.closeRepository(path: repoB.path)

        let relaunched = RepositoryViewModel(defaults: defaults)

        XCTAssertEqual(relaunched.openRepositories.map(\.path), [repoC.path, repoA.path])
        XCTAssertEqual(relaunched.selectedRepository?.path, repoA.path)
    }

    func testRelaunchDropsTabsWhoseRepoWasDeleted() throws {
        let repoA = try makeRepo(), repoB = try makeRepo()
        let first = RepositoryViewModel(defaults: defaults)
        [repoA, repoB].forEach { first.selectRepository(url: $0) }
        try FileManager.default.removeItem(at: repoB)

        let relaunched = RepositoryViewModel(defaults: defaults)

        XCTAssertEqual(relaunched.openRepositories.map(\.path), [repoA.path])
        XCTAssertEqual(relaunched.selectedRepository?.path, repoA.path)
    }

    func testDraggingTabOntoAnotherTakesItsPlace() throws {
        let viewModel = RepositoryViewModel(defaults: defaults)
        let repoA = try makeRepo(), repoB = try makeRepo(), repoC = try makeRepo()
        [repoA, repoB, repoC].forEach { viewModel.selectRepository(url: $0) }

        viewModel.moveRepository(path: repoC.path, onto: repoA.path)   // C to the front
        XCTAssertEqual(viewModel.openRepositories.map(\.path), [repoC.path, repoA.path, repoB.path])

        viewModel.moveRepository(path: repoC.path, onto: repoB.path)   // C back to the end
        XCTAssertEqual(viewModel.openRepositories.map(\.path), [repoA.path, repoB.path, repoC.path])

        viewModel.moveRepository(path: "/not/a/tab", onto: repoA.path)  // foreign drops ignored
        XCTAssertEqual(viewModel.openRepositories.map(\.path), [repoA.path, repoB.path, repoC.path])
    }

    func testRemovingRecentKeepsOpenTabAndPersists() throws {
        let viewModel = RepositoryViewModel(defaults: defaults)
        let repoA = try makeRepo(), repoB = try makeRepo()
        [repoA, repoB].forEach { viewModel.selectRepository(url: $0) }

        viewModel.removeRecent(path: repoA.path)

        XCTAssertEqual(viewModel.recentRepositories.map(\.path), [repoB.path])
        XCTAssertEqual(viewModel.openRepositories.map(\.path), [repoA.path, repoB.path])  // tab untouched
        XCTAssertEqual(RepositoryViewModel(defaults: defaults).recentRepositories.map(\.path), [repoB.path])
    }

    func testAdjacentTabWrapsAround() throws {
        let viewModel = RepositoryViewModel(defaults: defaults)
        let repoA = try makeRepo(), repoB = try makeRepo(), repoC = try makeRepo()
        [repoA, repoB, repoC].forEach { viewModel.selectRepository(url: $0) }   // C selected

        viewModel.selectAdjacentTab(1)
        XCTAssertEqual(viewModel.selectedRepository?.path, repoA.path)            // ⌃Tab past the end → first
        viewModel.selectAdjacentTab(-1)
        XCTAssertEqual(viewModel.selectedRepository?.path, repoC.path)            // ⌃⇧Tab before first → last
        XCTAssertEqual(viewModel.openRepositories.map(\.path), [repoA.path, repoB.path, repoC.path])
    }

    func testDroppingFoldersOpensReposAndNamesTheRest() throws {
        let viewModel = RepositoryViewModel(defaults: defaults)
        let repo = try makeRepo()
        let plainFolder = FileManager.default.temporaryDirectory.appendingPathComponent("photos-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: plainFolder, withIntermediateDirectories: true)
        roots.append(plainFolder)

        viewModel.openDropped([repo, plainFolder])

        XCTAssertEqual(viewModel.openRepositories.map(\.path), [repo.path])
        XCTAssertEqual(viewModel.selectedRepository?.path, repo.path)
        XCTAssertTrue(viewModel.errorMessage?.contains(plainFolder.lastPathComponent) == true)
    }

    func testDroppingOnlyReposShowsNoWarning() throws {
        let viewModel = RepositoryViewModel(defaults: defaults)
        viewModel.openDropped([try makeRepo(), try makeRepo()])

        XCTAssertEqual(viewModel.openRepositories.count, 2)
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Helpers

    private func makeRepo() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".git/info"),
            withIntermediateDirectories: true
        )
        roots.append(root)
        return root
    }
}

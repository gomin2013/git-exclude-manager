import XCTest
import Shared
@testable import GitExcludeManagerApp
@testable import GitExcludeManagerHelper

/// App ↔ helper over real XPC: `HelperService` behind an anonymous in-process listener,
/// so requests/replies/NSErrors go through NSXPC serialization exactly as in production (minus launchd).
@MainActor
final class XPCIntegrationTests: XCTestCase {
    /// Same as the production delegate minus the code-signing check (the test runner isn't the app).
    private final class TestDelegate: NSObject, NSXPCListenerDelegate {
        func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
            connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
            connection.exportedObject = HelperService()
            connection.resume()
            return true
        }
    }

    private var listener: NSXPCListener!
    private let delegate = TestDelegate()
    private var xpc: XPCService!
    private var roots: [URL] = []

    override func setUp() async throws {
        listener = NSXPCListener.anonymous()
        listener.delegate = delegate
        listener.resume()
        xpc = XPCService(endpoint: listener.endpoint)
    }

    override func tearDown() async throws {
        await xpc.invalidate()
        listener.invalidate()
        roots.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    // MARK: - XPCService ↔ HelperService

    func testReadWriteRestoreRoundTrip() async throws {
        let repo = try makeRepo(exclude: "v1\n")

        let initial = try await read(repo)
        try await call { done in await self.xpc.writeExcludeFile(repoPath: repo.path, content: "v2\n", completion: done) }
        let written = try await read(repo)
        try await call { done in await self.xpc.restoreBackup(repoPath: repo.path, completion: done) }
        let restored = try await read(repo)

        XCTAssertEqual([initial, written, restored], ["v1\n", "v2\n", "v1\n"])
    }

    func testHelperErrorsSurviveXPCAsHelperError() async {
        do {
            _ = try await read(URL(fileURLWithPath: "/tmp/definitely-not-a-repo-\(UUID())"))
            XCTFail("expected an error")
        } catch {
            guard case HelperError.invalidRepository = error else { return XCTFail("got \(error)") }
        }
    }

    func testPingAndValidate() async {
        let alive = await withCheckedContinuation { cont in
            Task { await xpc.ping { cont.resume(returning: $0) } }
        }
        let valid = await withCheckedContinuation { cont in
            Task { await xpc.validatePattern("*.log") { cont.resume(returning: $0) } }
        }
        XCTAssertTrue(alive)
        XCTAssertTrue(valid)
    }

    // MARK: - PatternsViewModel end to end

    func testViewModelLoadEditSaveAndRestore() async throws {
        let repo = try makeRepo(exclude: "# notes\n*.log\n")
        let viewModel = PatternsViewModel(xpcService: xpc)

        viewModel.loadPatterns(from: GitRepository(path: repo.path))
        try await waitUntil { !viewModel.isLoading }
        XCTAssertEqual(viewModel.patterns.map(\.kind), [.comment, .pattern])

        viewModel.addSection()
        try await waitUntil { !viewModel.isSaving }
        viewModel.renameSection(viewModel.patterns[2].id, to: "Env")
        try await waitUntil { !viewModel.isSaving }
        viewModel.addPattern(GitExcludePattern(pattern: ".env"))
        try await waitUntil { !viewModel.isSaving }
        XCTAssertEqual(try contents(repo), "# notes\n*.log\n\n# Env\n.env\n")

        viewModel.togglePattern(viewModel.patterns[1].id)
        try await waitUntil { !viewModel.isSaving }
        XCTAssertEqual(try contents(repo), "# notes\n#*.log\n\n# Env\n.env\n")

        viewModel.restorePreviousVersion()
        try await waitUntil { (try? self.contents(repo)) == "# notes\n*.log\n\n# Env\n.env\n" && !viewModel.isLoading }
        XCTAssertTrue(viewModel.patterns[1].isEnabled)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testViewModelSuggestionsComeFromOtherReposOverXPC() async throws {
        let current = try makeRepo(exclude: ".DS_Store\n")
        let other = try makeRepo(exclude: ".DS_Store\n.env\n")
        let viewModel = PatternsViewModel(xpcService: xpc)
        viewModel.loadPatterns(from: GitRepository(path: current.path))
        try await waitUntil { !viewModel.isLoading }

        viewModel.loadSuggestions(from: [GitRepository(path: other.path), GitRepository(path: "/nope")])
        try await waitUntil { !viewModel.suggestions.isEmpty }

        XCTAssertEqual(viewModel.suggestions.map(\.pattern), [".env"])
    }

    func testViewModelShowsHelperErrorForMissingRepo() async throws {
        let viewModel = PatternsViewModel(xpcService: xpc)
        viewModel.loadPatterns(from: GitRepository(path: "/tmp/missing-\(UUID())"))
        try await waitUntil { !viewModel.isLoading }
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Helpers

    private func makeRepo(exclude: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git/info"), withIntermediateDirectories: true)
        try exclude.write(to: root.appendingPathComponent(".git/info/exclude"), atomically: true, encoding: .utf8)
        roots.append(root)
        return root
    }

    private func contents(_ repo: URL) throws -> String {
        try String(contentsOf: repo.appendingPathComponent(".git/info/exclude"), encoding: .utf8)
    }

    private func read(_ repo: URL) async throws -> String {
        let data = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            Task { await xpc.readExcludeFile(repoPath: repo.path) { cont.resume(with: $0.mapError { $0 }) } }
        }
        return String(decoding: data, as: UTF8.self)
    }

    private func call(
        _ body: @escaping (@escaping @Sendable (Result<Void, HelperError>) -> Void) async -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            Task { await body { cont.resume(with: $0.mapError { $0 }) } }
        }
    }

    /// Polls on the main actor (the view model hops results back to main).
    private func waitUntil(timeout: TimeInterval = 5, _ condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        try await Task.sleep(for: .milliseconds(20))
        while !condition() {
            guard Date() < deadline else { return XCTFail("timed out waiting for condition") }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}

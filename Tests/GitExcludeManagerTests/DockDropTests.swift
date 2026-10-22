import AppKit
import XCTest
@testable import GitExcludeManagerApp

/// A repository folder dropped on the Dock icon opens as a tab, same path as dropping it on the window.
@MainActor
final class DockDropTests: XCTestCase {
    // MARK: - Delegate

    func testDropsBeforeTheWindowWaitThenArriveOnce() {
        let delegate = DockDropDelegate()
        var received: [[URL]] = []
        let first = URL(fileURLWithPath: "/tmp/a"), second = URL(fileURLWithPath: "/tmp/b")

        delegate.application(NSApplication.shared, open: [first])  // cold launch: no window yet
        XCTAssertEqual(delegate.pending, [first])
        delegate.onOpen = { received.append($0) }
        delegate.application(NSApplication.shared, open: [second])  // window up: straight through

        XCTAssertEqual(received, [[first], [second]])
        XCTAssertEqual(delegate.pending, [])
    }

    // MARK: - Info.plist

    /// Alternate, never Default/Owner: the Dock icon accepts the drop, but Finder never opens public.folder with this app.
    func testInfoPlistAcceptsDropsWithoutBecomingTheDefault() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/GitExcludeManagerApp/Info.plist")
        let plist = try XCTUnwrap(NSDictionary(contentsOf: url))
        let types = try XCTUnwrap(plist["CFBundleDocumentTypes"] as? [[String: Any]])
        XCTAssertEqual(types.count, 1)
        XCTAssertEqual(types[0]["LSItemContentTypes"] as? [String], ["public.folder"])
        XCTAssertEqual(types[0]["LSHandlerRank"] as? String, "Alternate")
    }

    // MARK: - Open a dropped folder

    func testDroppedRepositoryOpensAsTabAndOtherFoldersAreNamed() throws {
        let repo = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let plain = FileManager.default.temporaryDirectory.appendingPathComponent("not-a-repo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: repo.appendingPathComponent(".git/info"),
                                                withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)
        defer { [repo, plain].forEach { try? FileManager.default.removeItem(at: $0) } }
        let viewModel = RepositoryViewModel(defaults: try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString)))

        viewModel.openDropped([repo, plain])

        XCTAssertEqual(viewModel.selectedRepository?.path, repo.path)
        XCTAssertTrue(viewModel.errorMessage?.contains(plain.lastPathComponent) == true)
    }
}

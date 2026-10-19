import XCTest
import Shared
@testable import GitExcludeManagerApp

/// Photoshop-style History panel: last `EditHistory.limit` (30) states, jump back and forth, pinned snapshots, remove.
@MainActor
final class EditHistoryTests: XCTestCase {
    private func items(_ names: String...) -> [GitExcludePattern] { names.map { GitExcludePattern(pattern: $0) } }

    func testOpeningIsTheFirstStateAndIsPinned() {
        let history = EditHistory(opened: items("a"), label: "Opened")
        XCTAssertEqual(history.states.map(\.label), ["Opened"])
        XCTAssertEqual(history.pinned.map(\.label), ["Opened"])
        XCTAssertEqual(history.currentState?.label, "Opened")
    }

    func testJumpBackThenEditDropsTheStatesAhead() throws {
        var history = EditHistory(opened: items("a"), label: "Opened")
        history.record("Add b", items: items("a", "b"))
        history.record("Add c", items: items("a", "b", "c"))
        let first = history.states[0]

        XCTAssertEqual(history.jump(to: first.id)?.map(\.pattern), ["a"])
        XCTAssertTrue(history.isAhead(history.states[2].id))  // dimmed, still there to jump forward to

        history.record("Add d", items: items("a", "d"))
        XCTAssertEqual(history.states.map(\.label), ["Opened", "Add d"])
        XCTAssertEqual(history.currentState?.label, "Add d")
    }

    func testKeepsTheLastLimitStatesButNeverLosesPinned() {
        XCTAssertEqual(EditHistory.limit, 30)
        var history = EditHistory(opened: items(), label: "Opened")
        let edits = EditHistory.limit + 2
        for index in 1...edits { history.record("Edit \(index)", items: items("\(index)")) }
        XCTAssertEqual(history.states.count, EditHistory.limit)
        XCTAssertEqual(history.states.first?.label, "Edit 3")
        XCTAssertEqual(history.currentState?.label, "Edit \(edits)")
        XCTAssertEqual(history.pinned.map(\.label), ["Opened"])  // the original survives as a snapshot
    }

    func testPinAndUnpin() throws {
        var history = EditHistory(opened: items("a"), label: "Opened")
        history.record("Add b", items: items("a", "b"))
        let state = try XCTUnwrap(history.currentState)

        history.togglePin(state.id)
        XCTAssertTrue(history.isPinned(state.id))
        history.togglePin(state.id)
        XCTAssertFalse(history.isPinned(state.id))
    }

    // MARK: - View model

    func testViewModelRecordsEditsAndJumpsBack() throws {
        let viewModel = PatternsViewModel()
        viewModel.patterns = items("a")
        viewModel.startHistory(key: "repo")

        viewModel.addPattern(GitExcludePattern(pattern: "b"))
        viewModel.deletePattern(viewModel.patterns[0].id)
        XCTAssertEqual(viewModel.patterns.map(\.pattern), ["b"])
        XCTAssertEqual(viewModel.history.states.count, 3)

        viewModel.goToHistory(viewModel.history.states[1].id)  // after "Add b"
        XCTAssertEqual(viewModel.patterns.map(\.pattern), ["a", "b"])

        let opened = try XCTUnwrap(viewModel.history.pinned.first)
        viewModel.restoreSnapshot(opened.id)
        XCTAssertEqual(viewModel.patterns.map(\.pattern), ["a"])
        XCTAssertEqual(viewModel.history.states.count, 3)  // restoring is itself undoable: Opened, Add b, Restore
    }

    func testHistoryIsKeptPerTab() {
        let viewModel = PatternsViewModel()
        viewModel.patterns = items("a")
        viewModel.startHistory(key: "one")
        viewModel.addPattern(GitExcludePattern(pattern: "b"))
        let one = viewModel.patterns

        viewModel.patterns = items("x")
        viewModel.startHistory(key: "two")
        viewModel.patterns = one
        viewModel.startHistory(key: "one")

        XCTAssertEqual(viewModel.history.states.count, 2)  // came back to tab one's history
    }

    func testRemoveOneStateKeepsCurrentAndPins() throws {
        var history = EditHistory(opened: items("a"), label: "Opened")
        history.record("Add b", items: items("a", "b"))
        history.record("Add c", items: items("a", "b", "c"))
        let opened = history.states[0], addB = history.states[1], addC = history.states[2]

        history.remove(addC.id)  // current: can't remove the state you're on
        XCTAssertEqual(history.states.count, 3)

        history.remove(addB.id)
        XCTAssertEqual(history.states.map(\.label), ["Opened", "Add c"])
        XCTAssertEqual(history.currentState?.label, "Add c", "current moves with the list")

        history.remove(opened.id)  // a pinned state leaves Recent, its pin stays
        XCTAssertEqual(history.states.map(\.label), ["Add c"])
        XCTAssertEqual(history.pinned.map(\.label), ["Opened"])
        history.unpin(opened.id)
        XCTAssertTrue(history.pinned.isEmpty)
    }
}

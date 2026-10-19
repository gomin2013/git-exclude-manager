import Foundation
import Shared

/// One point in an exclude file's edit history: what was done, when, and the whole file as it was after.
struct HistoryState: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let date = Date()
    let items: [GitExcludePattern]
}

/// Photoshop-style history: the last `limit` states (oldest first) with a current position — click one to go back,
/// later ones stay (dimmed) until the next edit replaces them — plus pinned snapshots that never fall off.
/// The file as opened is pinned automatically, so the oldest version is always one click away.
/// ponytail: session-only, in memory; persist to disk if people want history across launches.
struct EditHistory: Equatable {
    static let limit = 30

    private(set) var states: [HistoryState] = []
    private(set) var current = -1
    private(set) var pinned: [HistoryState] = []

    init() {}

    init(opened items: [GitExcludePattern], label: String) {
        let state = HistoryState(label: label, items: items)
        states = [state]
        current = 0
        pinned = [state]
    }

    var currentState: HistoryState? { states.indices.contains(current) ? states[current] : nil }

    /// A new edit: states ahead of the current one are dropped, the oldest beyond `limit` falls off.
    mutating func record(_ label: String, items: [GitExcludePattern]) {
        states.removeSubrange((current + 1)...)
        states.append(HistoryState(label: label, items: items))
        if states.count > Self.limit { states.removeFirst(states.count - Self.limit) }
        current = states.count - 1
    }

    /// Makes a recent state current; returns its items to apply.
    mutating func jump(to id: UUID) -> [GitExcludePattern]? {
        guard let index = states.firstIndex(where: { $0.id == id }) else { return nil }
        current = index
        return states[index].items
    }

    func isAhead(_ id: UUID) -> Bool { (states.firstIndex { $0.id == id } ?? -1) > current }
    func isPinned(_ id: UUID) -> Bool { pinned.contains { $0.id == id } }

    /// Removes one recent state — not the current one (you're standing on it). A pin of it stays: pins are snapshots.
    mutating func remove(_ id: UUID) {
        guard let index = states.firstIndex(where: { $0.id == id }), index != current else { return }
        states.remove(at: index)
        if index < current { current -= 1 }
    }

    mutating func unpin(_ id: UUID) { pinned.removeAll { $0.id == id } }

    mutating func togglePin(_ id: UUID) {
        if isPinned(id) {
            pinned.removeAll { $0.id == id }
        } else if let state = states.first(where: { $0.id == id }) {
            pinned.append(state)
        }
    }
}

extension PatternsViewModel {
    /// Starts (or resumes) the history of the file just loaded. `key` names the file — a tab's history survives
    /// switching away and back as long as the file is still what that history ended with.
    func startHistory(key: String) {
        if !historyKey.isEmpty { historyByKey[historyKey] = history }
        historyKey = key
        if let saved = historyByKey[key], saved.currentState?.items == patterns {
            history = saved
        } else {
            history = EditHistory(opened: patterns, label: localized("history.opened"))
        }
    }

    /// Last tab closed: forget the repository so no panel can still edit or write it. Its History is kept for when it
    /// opens again (like switching tabs); the Pattern Clipboard stays — it's meant to carry patterns between repos.
    func closeRepository() {
        if !historyKey.isEmpty { historyByKey[historyKey] = history }
        historyKey = ""
        history = EditHistory()
        selectedRepository = nil
        patterns = []
        suggestionSources = [:]
        searchText = ""
        errorMessage = nil
        editingSectionID = nil
    }

    /// Every edit goes through here: one history state, then the write.
    func commit(_ label: String) {
        history.record(label, items: patterns)
        savePatterns()
    }

    /// Click in the History panel: show and save the file as it was at that state.
    func goToHistory(_ id: UUID) {
        guard let items = history.jump(to: id) else { return }
        patterns = items
        savePatterns()
    }

    /// Click a pinned snapshot: bring it back as a new state, so that too can be undone.
    func restoreSnapshot(_ id: UUID) {
        guard let snapshot = history.pinned.first(where: { $0.id == id }) else { return }
        patterns = snapshot.items
        commit(localized("history.restore", args: snapshot.label))
    }
}

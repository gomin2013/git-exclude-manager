import Foundation
import AppKit
import SwiftUI  // Array.move(fromOffsets:toOffset:)
import Shared

/// A pattern copied into the Pattern Clipboard, with the repository it came from.
struct ClipboardItem: Identifiable, Equatable {
    let pattern: GitExcludePattern
    let repo: String
    var id: UUID { pattern.id }
}

/// A pattern other repositories use that the current one doesn't have yet.
struct PatternSuggestion: Identifiable, Equatable {
    let pattern: String
    let comment: String?
    var repos: [String]
    var id: String { pattern }
}

/// ViewModel for managing Git exclude patterns
@MainActor
public class PatternsViewModel: ObservableObject {
    @Published var patterns: [GitExcludePattern] = []
    @Published var selectedRepository: GitRepository?
    @Published var searchText: String = ""
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    /// Patterns read from an import file, waiting for the user to pick merge or replace.
    @Published var pendingImport: [GitExcludePattern]?
    /// Patterns collected with ⌘C across repositories (session only), pasted into another repo.
    @Published var clipboard: [ClipboardItem] = []
    /// Exclude-file items of the *other* recent repositories, keyed by repo name.
    @Published var suggestionSources: [String: [GitExcludePattern]] = [:]
    /// Set after a successful export; the status bar shows it briefly.
    @Published var lastExportURL: URL?
    /// Section whose heading is being typed. List(selection:) swallows clicks on an always-visible TextField,
    /// so the field only appears (focused) for this one: a new section, double-click, or Return.
    @Published var editingSectionID: UUID?
    /// History panel (EditHistory.swift): this file's recent states + pinned snapshots; other tabs' kept by key.
    @Published var history = EditHistory()
    var historyByKey: [String: EditHistory] = [:]
    var historyKey = ""

    private let xpcService: XPCService
    /// `-demo`: exclude files by repository path, in memory — read and written here instead of through the helper.
    private(set) var demoFiles: [String: [GitExcludePattern]]?

    public init(xpcService: XPCService = XPCService(), demoFiles: [String: [GitExcludePattern]]? = nil) {
        self.xpcService = xpcService
        self.demoFiles = demoFiles
    }

    // MARK: - Computed Properties

    var suggestions: [PatternSuggestion] {
        Self.suggestions(current: patterns, others: suggestionSources)
    }

    /// Enabled patterns from other repos that `current` lacks — most widely shared first, then A→Z.
    static func suggestions(
        current: [GitExcludePattern],
        others: [String: [GitExcludePattern]]
    ) -> [PatternSuggestion] {
        let existing = Set(current.filter { $0.kind == .pattern }.map(\.pattern))
        var byPattern: [String: PatternSuggestion] = [:]
        for (repo, items) in others {
            for item in items where item.kind == .pattern && item.isEnabled && !existing.contains(item.pattern) {
                var suggestion = byPattern[item.pattern]
                    ?? PatternSuggestion(pattern: item.pattern, comment: item.comment, repos: [])
                if !suggestion.repos.contains(repo) { suggestion.repos.append(repo) }
                byPattern[item.pattern] = suggestion
            }
        }
        return byPattern.values
            .map { PatternSuggestion(pattern: $0.pattern, comment: $0.comment, repos: $0.repos.sorted()) }
            .sorted {
                $0.repos.count != $1.repos.count ? $0.repos.count > $1.repos.count : $0.pattern < $1.pattern
            }
    }

    /// Reads the other repositories' exclude files (via the helper) to build suggestions.
    func loadSuggestions(from repositories: [GitRepository]) {
        Task {
            var sources: [String: [GitExcludePattern]] = [:]
            for repo in repositories {
                let items = await readItems(repoPath: repo.path)
                if !items.isEmpty { sources[repo.name] = items }
            }
            suggestionSources = sources
        }
    }

    func addSuggestion(_ suggestion: PatternSuggestion) {
        addPattern(GitExcludePattern(pattern: suggestion.pattern, comment: suggestion.comment))
    }

    // MARK: - Pattern Clipboard

    /// Adds the selected *patterns* (sections/comments skipped) in file order; already-collected text is kept once.
    /// Returns them as exclude-file text for the system pasteboard (the view writes it — keeps tests off the
    /// user's real clipboard).
    @discardableResult
    func copyToClipboard(_ ids: Set<UUID>, from repo: String) -> String {
        let selected = patterns.filter { ids.contains($0.id) && $0.kind == .pattern }
        let collected = Set(clipboard.map(\.pattern.pattern))
        clipboard += selected
            .filter { !collected.contains($0.pattern) }
            .map { ClipboardItem(pattern: $0, repo: repo) }
        return ExcludeParserService.serialize(selected)
    }

    /// Appends clipboard patterns this repository doesn't have yet; one save. Returns how many were added.
    @discardableResult
    func paste(_ items: [ClipboardItem]) -> Int {
        merge(items.map(\.pattern))
    }

    /// ⌘V: any text (another repo, a .gitignore) — pattern lines are added, comments/blank lines ignored.
    @discardableResult
    func pasteText(_ text: String) -> Int {
        merge(ExcludeParserService.parse(content: text))
    }

    func removeFromClipboard(_ id: UUID) {
        clipboard.removeAll { $0.id == id }
    }

    func clearClipboard() {
        clipboard.removeAll()
    }

    private func merge(_ incoming: [GitExcludePattern]) -> Int {
        var existing = Set(patterns.filter { $0.kind == .pattern }.map(\.pattern))
        let fresh = incoming.filter { existing.insert($0.pattern).inserted }   // also dedupes within incoming
        guard !fresh.isEmpty else { return 0 }
        patterns += fresh.map {
            GitExcludePattern(pattern: $0.pattern, isEnabled: $0.isEnabled, comment: $0.comment)  // new ids
        }
        commit(localized("history.paste", args: fresh.count))
        return fresh.count
    }

    /// Missing repo or file → no items (suggestions are best-effort).
    private func readItems(repoPath: String) async -> [GitExcludePattern] {
        if let demoFiles { return demoFiles[repoPath] ?? [] }
        return await withCheckedContinuation { continuation in
            Task {
                await xpcService.readExcludeFile(repoPath: repoPath) { result in
                    let items = (try? result.get()).flatMap { try? ExcludeParserService.parseItems(data: $0) }
                    continuation.resume(returning: items ?? [])
                }
            }
        }
    }

    var patternCount: Int { patterns.filter { $0.kind == .pattern }.count }
    var enabledCount: Int { patterns.filter { $0.kind == .pattern && $0.isEnabled }.count }

    /// All items, or only matching patterns while searching (sections/comments hidden).
    var filteredPatterns: [GitExcludePattern] {
        guard !searchText.isEmpty else { return patterns }
        return patterns.filter { pattern in
            pattern.kind == .pattern && (
            pattern.pattern.localizedCaseInsensitiveContains(searchText) ||
            (pattern.comment?.localizedCaseInsensitiveContains(searchText) ?? false))
        }
    }

    // MARK: - Public Interface

    /// Adds a new pattern and persists to file.
    func addPattern(_ pattern: GitExcludePattern) {
        self.patterns.append(pattern)
        commit(localized("history.add", args: pattern.pattern))
    }

    /// Appends an untitled section break with its heading open for typing; the user drags it into place.
    func addSection() {
        let section = GitExcludePattern(pattern: "", kind: .section)
        patterns.append(section)
        editingSectionID = section.id
        commit(localized("history.addSection"))
    }

    /// Sets a section heading ("" removes it).
    func renameSection(_ id: UUID, to title: String) {
        guard let index = patterns.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard patterns[index].pattern != trimmed else { return }
        patterns[index].pattern = trimmed
        commit(localized("history.rename", args: trimmed.isEmpty ? localized("history.untitledSection") : trimmed))
    }

    /// Edits an existing pattern and persists to file.
    func editPattern(_ pattern: GitExcludePattern) {
        // Editor only owns text + comment; keep enabled state, creation date and attached comment lines.
        if let index = self.patterns.firstIndex(where: { $0.id == pattern.id }) {
            self.patterns[index].pattern = pattern.pattern
            self.patterns[index].comment = pattern.comment
            self.patterns[index].modifiedAt = Date()
        }
        commit(localized("history.edit", args: pattern.pattern))
    }

    /// What a history label calls an item: the pattern, a section's heading, or a comment's first line.
    static func historyName(_ item: GitExcludePattern) -> String {
        switch item.kind {
        case .pattern: return item.pattern
        case .section: return item.pattern.isEmpty ? localized("history.untitledSection") : item.pattern
        case .comment: return String(item.pattern.prefix { $0 != "\n" })
        }
    }

    /// Deletes a pattern by ID and persists to file.
    func deletePattern(_ patternID: UUID) {
        let name = patterns.first { $0.id == patternID }.map(Self.historyName) ?? ""
        self.patterns.removeAll { $0.id == patternID }
        commit(localized("history.delete", args: name))
    }

    /// Toggles enabled/disabled state and persists to file.
    func togglePattern(_ patternID: UUID) {
        guard let index = self.patterns.firstIndex(where: { $0.id == patternID }) else { return }
        self.patterns[index].isEnabled.toggle()
        self.patterns[index].modifiedAt = Date()
        let item = patterns[index]
        commit(localized(item.isEnabled ? "history.turnOn" : "history.turnOff", args: item.pattern))
    }

    /// Loads patterns from `.git/info/exclude` via XPC helper.
    func loadPatterns(from repository: GitRepository) {
        selectedRepository = repository
        errorMessage = nil
        if let demoFiles {
            patterns = demoFiles[repository.path] ?? []
            startHistory(key: repository.path)
            return
        }
        isLoading = true

        Task {
            await xpcService.readExcludeFile(repoPath: repository.path) { result in
                // XPCService already hops to DispatchQueue.main before calling this closure.
                // We use Task { @MainActor in } so the compiler knows we're back on main actor.
                Task { @MainActor in
                    self.isLoading = false
                    switch result {
                    case .success(let data):
                        do {
                            self.patterns = try ExcludeParserService.parseItems(data: data)
                            self.startHistory(key: repository.path)
                            self.errorMessage = nil
                            // v1.0 wrote `pattern # comment`, which git reads as one pattern that matches nothing.
                            // Rewrite it right away (the helper keeps the old file as exclude.bak).
                            if let text = String(bytes: data, encoding: .utf8),
                               ExcludeParserService.hasInlineComments(content: text) {
                                self.savePatterns()
                            }
                        } catch let helperError as HelperError {
                            self.errorMessage = helperError.localizedDescription
                        } catch {
                            self.errorMessage = HelperError.unknown(error.localizedDescription).localizedDescription
                        }
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    /// Exports patterns to a file chosen by the user via NSSavePanel.
    func exportPatterns() {
        guard let repository = selectedRepository else {
            self.errorMessage = NSLocalizedString("error.noRepository", comment: "")
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(repository.name)-exclude-patterns.txt"
        panel.allowedContentTypes = [.plainText]
        panel.title = NSLocalizedString("btn.export", comment: "")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let content = ExcludeParserService.serialize(patterns)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            lastExportURL = url
        } catch {
            self.errorMessage = HelperError.fileWriteError(error.localizedDescription).localizedDescription
        }
    }

    /// Imports patterns from a file chosen by the user via NSOpenPanel.
    func importPatterns() {
        guard selectedRepository != nil else {
            self.errorMessage = NSLocalizedString("error.noRepository", comment: "")
            return
        }

        // No content-type filter + hidden files: `.gitignore` has no extension and is hidden.
        let panel = NSOpenPanel()
        panel.showsHiddenFiles = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = NSLocalizedString("btn.import", comment: "")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            pendingImport = ExcludeParserService.parseItems(content: content)
        } catch {
            self.errorMessage = HelperError.fileReadError(error.localizedDescription).localizedDescription
        }
    }

    /// Reorders patterns (drag in the list). Attached comment lines move with their pattern.
    func movePatterns(from source: IndexSet, to destination: Int) {
        // git's default header stays first: it can't move, and nothing can be dropped above it.
        guard !source.contains(where: { patterns[$0].isGitDefaultHeader }) else { return }
        let floor = patterns.first?.isGitDefaultHeader == true ? 1 : 0
        patterns.move(fromOffsets: source, toOffset: max(destination, floor))
        commit(localized("history.move"))
    }

    /// Applies an import. Merge appends only patterns not already present (existing ones win).
    func applyImport(_ imported: [GitExcludePattern], replace: Bool) {
        if replace {
            patterns = imported
        } else {
            // Merge brings in new patterns only; the file's own sections/comments stay as they are.
            let existing = Set(patterns.filter { $0.kind == .pattern }.map(\.pattern))
            patterns += imported.filter { $0.kind == .pattern && !existing.contains($0.pattern) }
        }
        pendingImport = nil
        commit(localized("history.import", args: imported.count))
    }

    /// Reverts the exclude file to the version before the last save, then reloads.
    /// Calling it again swaps back (the restore itself is backed up).
    func restorePreviousVersion() {
        guard let repository = selectedRepository, demoFiles == nil else { return }

        Task {
            await xpcService.restoreBackup(repoPath: repository.path) { result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        self.loadPatterns(from: repository)
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    /// Invalidates the XPC connection (call when app goes to background).
    func invalidateXPC() {
        Task { await xpcService.invalidate() }
    }

    // MARK: - Private Methods

    /// Serializes current patterns and writes to file via XPC helper.
    /// Writes without recording history — `commit(_:)` records; jumping through history writes only.
    func savePatterns() {
        guard let repository = selectedRepository else { return }
        if demoFiles != nil {
            demoFiles?[repository.path] = patterns
            return
        }

        isSaving = true
        let content = ExcludeParserService.serialize(patterns)

        Task {
            await xpcService.writeExcludeFile(repoPath: repository.path, content: content) { result in
                Task { @MainActor in
                    self.isSaving = false
                    if case .failure(let error) = result {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

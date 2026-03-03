import Foundation
import AppKit
import SwiftUI  // Array.move(fromOffsets:toOffset:)
import Shared

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
    /// Exclude-file items of the *other* recent repositories, keyed by repo name.
    @Published var suggestionSources: [String: [GitExcludePattern]] = [:]
    /// Set after a successful export; the status bar shows it briefly.
    @Published var lastExportURL: URL?

    private let xpcService: XPCService

    public init(xpcService: XPCService = XPCService()) {
        self.xpcService = xpcService
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

    /// Missing repo or file → no items (suggestions are best-effort).
    private func readItems(repoPath: String) async -> [GitExcludePattern] {
        await withCheckedContinuation { continuation in
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
        savePatterns()
    }

    /// Appends an untitled section break; the user drags it into place and names it inline.
    func addSection() {
        patterns.append(GitExcludePattern(pattern: "", kind: .section))
        savePatterns()
    }

    /// Sets a section heading ("" removes it).
    func renameSection(_ id: UUID, to title: String) {
        guard let index = patterns.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard patterns[index].pattern != trimmed else { return }
        patterns[index].pattern = trimmed
        savePatterns()
    }

    /// Edits an existing pattern and persists to file.
    func editPattern(_ pattern: GitExcludePattern) {
        // Editor only owns text + comment; keep enabled state, creation date and attached comment lines.
        if let index = self.patterns.firstIndex(where: { $0.id == pattern.id }) {
            self.patterns[index].pattern = pattern.pattern
            self.patterns[index].comment = pattern.comment
            self.patterns[index].modifiedAt = Date()
        }
        savePatterns()
    }

    /// Deletes a pattern by ID and persists to file.
    func deletePattern(_ patternID: UUID) {
        self.patterns.removeAll { $0.id == patternID }
        savePatterns()
    }

    /// Toggles enabled/disabled state and persists to file.
    func togglePattern(_ patternID: UUID) {
        if let index = self.patterns.firstIndex(where: { $0.id == patternID }) {
            self.patterns[index].isEnabled.toggle()
            self.patterns[index].modifiedAt = Date()
        }
        savePatterns()
    }

    /// Loads patterns from `.git/info/exclude` via XPC helper.
    func loadPatterns(from repository: GitRepository) {
        selectedRepository = repository
        isLoading = true
        errorMessage = nil

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
                            self.errorMessage = nil
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
        savePatterns()
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
        savePatterns()
    }

    /// Reverts the exclude file to the version before the last save, then reloads.
    /// Calling it again swaps back (the restore itself is backed up).
    func restorePreviousVersion() {
        guard let repository = selectedRepository else { return }

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
    private func savePatterns() {
        guard let repository = selectedRepository else { return }

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

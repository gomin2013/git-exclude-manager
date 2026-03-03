import Foundation
import AppKit
import Shared

/// ViewModel for repository selection and management
@MainActor
public class RepositoryViewModel: ObservableObject {
    @Published var selectedRepository: GitRepository? { didSet { saveTabs() } }
    @Published var recentRepositories: [GitRepository] = []
    /// Repositories shown as tabs, in the user's order. Restored on relaunch with the selected tab.
    @Published var openRepositories: [GitRepository] = [] { didSet { saveTabs() } }
    @Published var errorMessage: String?

    private static let recentRepositoriesKey = "app.recentRepositories"
    private static let maxRecentCount = 10
    private static let openTabsKey = "app.openTabs"
    private static let selectedTabKey = "app.selectedTab"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadRecentRepositories()
    }

    // MARK: - Public Interface

    /// Selects a repository by URL, validates it, and persists to recents.
    func selectRepository(url: URL) {
        let path = url.path
        guard GitRepository.isValidRepository(at: path) else {
            self.errorMessage = localized("error.notRepository", args: url.lastPathComponent)
            return
        }

        let repo = GitRepository(path: path, lastAccessedAt: Date())
        if let index = openRepositories.firstIndex(where: { $0.path == path }) {
            openRepositories[index] = repo
        } else {
            openRepositories.append(repo)
        }
        self.selectedRepository = repo
        self.errorMessage = nil
        addToRecents(repo)
        saveRecentRepositories()
    }

    /// Switches to an already-open tab.
    func switchTo(_ repo: GitRepository) {
        selectRepository(url: URL(fileURLWithPath: repo.path))
    }

    /// Folders dragged from Finder: Git repositories open as tabs; anything else is named in one warning.
    func openDropped(_ urls: [URL]) {
        let rejected = urls.filter { !GitRepository.isValidRepository(at: $0.path) }
        urls.filter { GitRepository.isValidRepository(at: $0.path) }.forEach { selectRepository(url: $0) }
        errorMessage = rejected.isEmpty
            ? nil
            : localized("error.notRepository", args: rejected.map(\.lastPathComponent).joined(separator: ", "))
    }

    /// ⌃Tab (+1) / ⌃⇧Tab (−1) — wraps around like browser tabs.
    func selectAdjacentTab(_ offset: Int) {
        guard openRepositories.count > 1,
              let current = openRepositories.firstIndex(where: { $0.path == selectedRepository?.path }) else { return }
        let count = openRepositories.count
        switchTo(openRepositories[((current + offset) % count + count) % count])
    }

    /// Forgets a repository in the Open Repository list (history only — files and open tabs are untouched).
    func removeRecent(path: String) {
        recentRepositories.removeAll { $0.path == path }
        saveRecentRepositories()
    }

    /// Drag-and-drop: the dragged tab takes the target tab's position (others shift).
    /// Ignores paths that aren't open tabs (e.g. text dragged in from another app).
    func moveRepository(path: String, onto targetPath: String) {
        guard path != targetPath,
              let from = openRepositories.firstIndex(where: { $0.path == path }),
              let to = openRepositories.firstIndex(where: { $0.path == targetPath }) else { return }
        openRepositories.insert(openRepositories.remove(at: from), at: to)
    }

    /// Closes a tab. The last tab stays open; closing the active tab activates the first remaining one.
    func closeRepository(path: String) {
        guard openRepositories.count > 1 else { return }
        openRepositories.removeAll { $0.path == path }
        if selectedRepository?.path == path {
            selectedRepository = openRepositories.first
        }
    }

    /// Presents NSOpenPanel for folder selection and calls selectRepository.
    func browseRepository() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = NSLocalizedString("btn.browse", comment: "")
        panel.title = NSLocalizedString("label.repository", comment: "")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        selectRepository(url: url)
    }

    /// Loads recent repositories from UserDefaults.
    /// Also restores tabs (order + selection); tabs whose repo no longer exists are dropped.
    func loadRecentRepositories() {
        // Read saved tabs before assigning anything: the didSet observers below overwrite them.
        let savedTabs = defaults.stringArray(forKey: Self.openTabsKey) ?? []
        let savedSelection = defaults.string(forKey: Self.selectedTabKey)

        recentRepositories = defaults.data(forKey: Self.recentRepositoriesKey)
            .flatMap { try? JSONDecoder().decode([GitRepository].self, from: $0) } ?? []

        let tabs = savedTabs
            .filter { GitRepository.isValidRepository(at: $0) }
            .map { path in
                recentRepositories.first { $0.path == path } ?? GitRepository(path: path, lastAccessedAt: Date())
            }
        openRepositories = tabs.isEmpty ? Array(recentRepositories.prefix(1)) : tabs
        selectedRepository = openRepositories.first { $0.path == savedSelection } ?? openRepositories.first
    }

    // MARK: - Private Methods

    private func addToRecents(_ repo: GitRepository) {
        recentRepositories.removeAll { $0.path == repo.path }
        recentRepositories.insert(repo, at: 0)
        if recentRepositories.count > Self.maxRecentCount {
            recentRepositories = Array(recentRepositories.prefix(Self.maxRecentCount))
        }
    }

    private func saveTabs() {
        defaults.set(openRepositories.map(\.path), forKey: Self.openTabsKey)
        defaults.set(selectedRepository?.path, forKey: Self.selectedTabKey)
    }

    private func saveRecentRepositories() {
        guard let data = try? JSONEncoder().encode(recentRepositories) else { return }
        defaults.set(data, forKey: Self.recentRepositoriesKey)
    }
}

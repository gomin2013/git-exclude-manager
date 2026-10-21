import AppKit
import Shared

/// `open GitExcludeManager.app --args -demo` — three sample repositories held in memory, for screenshots and
/// recordings without real repository paths (steering: screenshots come from -demo only). Nothing is read from or
/// written to disk, and tabs / recents go to a throwaway defaults suite.
enum DemoData {
    static let isEnabled = CommandLine.arguments.contains("-demo")

    /// UI settings (@AppStorage, language) — a separate suite in demo mode so a demo never changes the real ones.
    /// Set them before launching, e.g. `defaults write com.gitexcludemanager.demo-ui ui.toolPanel history`.
    /// (Launch flags like `-ui.toolPanel history` are not an option: the bundled app opens no window when it is
    /// launched with a bare value argument.) `nonisolated(unsafe)`: UserDefaults is thread-safe, just not Sendable.
    nonisolated(unsafe) static let defaults: UserDefaults = isEnabled
        ? UserDefaults(suiteName: "com.gitexcludemanager.demo-ui") ?? .standard
        : .standard

    static let repositories: [GitRepository] = ["acme-web", "acme-api", "dotfiles"].map {
        GitRepository(path: NSHomeDirectory() + "/Developer/" + $0)
    }

    /// Exclude files by repository path, as they would be written on disk.
    static var files: [String: [GitExcludePattern]] {
        let texts = [
            GitExcludePattern.gitDefaultHeader + "\n" + """

            # Editors
            .idea/
            .vscode/settings.json
            *.swp

            # Secrets
            ## local API keys
            .env.local
            config/master.key

            # Claude Code
            ## personal agent notes
            CLAUDE.local.md
            .claude/worktrees/
            #.claude/settings.local.json

            """,
            """
            # Editors
            .idea/
            .DS_Store

            # Local
            coverage/
            ## turbo + eslint caches
            node_modules/.cache/

            """,
            """
            .DS_Store
            ## machine-specific shell config
            *.local.zsh

            """
        ]
        return Dictionary(uniqueKeysWithValues: zip(repositories.map(\.path),
                                                    texts.map(ExcludeParserService.parseItems(content:))))
    }

    /// A couple of edits and two copied patterns, so History and the Pattern Clipboard have something to show.
    @MainActor
    static func seed(_ patternsVM: PatternsViewModel) {
        guard let web = repositories.first, let api = repositories.dropFirst().first else { return }
        patternsVM.loadPatterns(from: web)
        patternsVM.addPattern(GitExcludePattern(pattern: "*.log", comment: "runtime logs"))
        if let swp = patternsVM.patterns.first(where: { $0.pattern == "*.swp" }) { patternsVM.togglePattern(swp.id) }
        if let added = patternsVM.history.states.dropFirst().first { patternsVM.history.togglePin(added.id) }
        patternsVM.clipboard = (files[api.path] ?? [])
            .filter { ["coverage/", "node_modules/.cache/"].contains($0.pattern) }
            .map { ClipboardItem(pattern: $0, repo: api.name) }
        // 1100×800 near the top-left for scripts/capture-screenshots.sh (resizing another app's window from a
        // script needs Accessibility access)
        if let window = NSApp.windows.first(where: \.isVisible), let screen = window.screen ?? NSScreen.main {
            window.setFrame(NSRect(x: 80, y: screen.frame.maxY - 880, width: 1100, height: 800), display: true)
        }
    }
}

import SwiftUI
import Shared
import ServiceManagement

@main
struct GitExcludeManagerApp: App {
    /// `-demo` (DemoData): sample repositories in memory — screenshots without real paths, nothing written.
    @StateObject private var patternsVM = PatternsViewModel(demoFiles: DemoData.isEnabled ? DemoData.files : nil)
    @StateObject private var repositoryVM = DemoData.isEnabled
        ? RepositoryViewModel(demo: DemoData.repositories)
        : RepositoryViewModel()
    // Use the singleton so every L() call shares the same bundle
    @StateObject private var languageService = LanguageService.shared
    /// Repository folders dropped on the Dock icon open as tabs, like dropping them on the window.
    @NSApplicationDelegateAdaptor(DockDropDelegate.self) private var dockDrop

    @Environment(\.scenePhase) private var scenePhase

    init() {
        Self.registerHelper()
    }

    /// Registers the bundled LaunchAgent so launchd starts the helper on demand.
    /// Only meaningful inside a .app built by `scripts/build-app.sh`; `swift run` has no bundle.
    private static func registerHelper() {
        // `-demo` never writes, so it never registers either: a demo run of a build copy can't replace the installed
        // app's LaunchAgent registration (same rule as hosts-manager).
        guard Bundle.main.bundleURL.pathExtension == "app", !DemoData.isEnabled else { return }
        let service = SMAppService.agent(plistName: "com.gitexcludemanager.helper.plist")
        guard service.status != .enabled else { return }
        do {
            try service.register()
        } catch {
            NSLog("Helper registration failed: \(error.localizedDescription)")
        }
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    var body: some Scene {
        // `Window`, not `WindowGroup`: one main window — a repository dropped on the Dock icon opens as a tab
        // in it instead of SwiftUI opening a second copy of the window.
        Window("Git Exclude Manager", id: "main") {
            patternsView
                .frame(minWidth: 820, minHeight: 540)
                // Inject as environment so child views can observe language changes
                .environmentObject(languageService)
                .defaultAppStorage(DemoData.defaults)
                .task {
                    dockDrop.onOpen = { [repositoryVM] urls in repositoryVM.openDropped(urls) }
                    if DemoData.isEnabled { DemoData.seed(patternsVM) }
                }
                .task { await UpdateChecker.checkIfDue() }   // off unless turned on in About (`-demo`: always off)
        }
        .windowResizability(.contentSize)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                patternsVM.invalidateXPC()
            }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button(localized("update.check")) { Task { await UpdateChecker.check(manual: true) } }
            }
            CommandGroup(replacing: .newItem) { }
            // No Help Book: Help › opens the Help side panel (PatternsView observes ui.toolPanel via @AppStorage)
            CommandGroup(replacing: .help) {
                Button(localized("menu.helpWindow")) {
                    DemoData.defaults.set(ToolPanel.help.rawValue, forKey: "ui.toolPanel")
                }
                .keyboardShortcut("?", modifiers: .command)
            }
            // Menu-bar "Repository" menu: shortcuts show next to each item, so they're discoverable.
            // (⌘N add pattern and ⌘F search live on their buttons in PatternsView.)
            CommandMenu(localized("menu.repository")) {
                Button(localized("btn.openRepo") + "…") { repositoryVM.browseRepository() }
                    .keyboardShortcut("o")
                Button(localized("menu.newSection")) { patternsVM.addSection() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(patternsVM.selectedRepository == nil)
                Button(localized("btn.restore")) { patternsVM.restorePreviousVersion() }
                    .disabled(patternsVM.selectedRepository == nil)

                Divider()

                Button(localized("menu.nextTab")) { switchTab { repositoryVM.selectAdjacentTab(1) } }
                    .keyboardShortcut(.tab, modifiers: .control)
                Button(localized("menu.previousTab")) { switchTab { repositoryVM.selectAdjacentTab(-1) } }
                    .keyboardShortcut(.tab, modifiers: [.control, .shift])

                Divider()

                // Like Safari's Window menu: open tabs by name, ⌘1…⌘9
                let firstNine = Array(repositoryVM.openRepositories.prefix(9).enumerated())
                ForEach(firstNine, id: \.element.path) { index, repo in
                    Button(repo.name) { switchTab { repositoryVM.switchTo(repo) } }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
        }
    }

    private var patternsView: some View {
        PatternsView(patternsVM: patternsVM, repositoryVM: repositoryVM)
    }

    /// Same as clicking a tab: clear the search so the new repo's list isn't filtered.
    private func switchTab(_ change: () -> Void) {
        patternsVM.searchText = ""
        change()
    }
}

import SwiftUI
import Shared

/// Main pattern list view — 2-column layout matching .prototype/main.html
struct PatternsView: View {
    @ObservedObject var patternsVM: PatternsViewModel
    @ObservedObject var repositoryVM: RepositoryViewModel
    @ObservedObject var languageService: LanguageService

    // Observe environment language so view body re-evaluates on language switch
    @EnvironmentObject private var envLanguage: LanguageService

    @State private var showingEditor = false
    @State private var patternToEdit: GitExcludePattern?
    @State private var showingOpenRepo = false
    @State private var showingRawPreview = false
    @State private var showingDeleteConfirm = false
    @State private var showingAbout = false
    @State private var isDropTargeted = false
    /// Right-column panels can be folded; remembered across launches.
    @AppStorage("ui.clipboardCollapsed") private var clipboardCollapsed = false
    @AppStorage("ui.suggestionsCollapsed") private var suggestionsCollapsed = false
    @AppStorage("ui.chatCollapsed") private var chatCollapsed = false
    @AppStorage("ui.helpCollapsed") private var helpCollapsed = true  // folded by default: don't squeeze the chat
    @State private var patternToDelete: UUID?
    @State private var colorScheme: SettingsDropdownView.ColorSchemePreference = .system
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            RepositoryTabBar(
                repositoryVM: repositoryVM,
                onTabSwitch: { patternsVM.searchText = "" },
                onOpenRepository: { showingOpenRepo = true }
            )
            HSplitView {
                patternPanel
                    .frame(minWidth: 340)
                VStack(spacing: 0) {
                    ClipboardPanel(patternsVM: patternsVM, isCollapsed: $clipboardCollapsed)
                    Divider()
                    SuggestionsPanel(
                        patternsVM: patternsVM,
                        isCollapsed: $suggestionsCollapsed,
                        fillsColumn: chatCollapsed && helpCollapsed
                    )
                    Divider()
                    ChatPanel(
                        patternsVM: patternsVM,
                        repositoryName: repositoryVM.selectedRepository?.name,
                        isCollapsed: $chatCollapsed
                    )
                    Divider()
                    HelpPanel(isCollapsed: $helpCollapsed)
                    // Nothing expanded that can grow: keep the headers at the top instead of centered
                    if chatCollapsed && helpCollapsed && (suggestionsCollapsed || patternsVM.suggestions.isEmpty) {
                        Spacer(minLength: 0)
                    }
                }
                .frame(width: 340)
            }
        }
        .frame(minWidth: 680, minHeight: 500)
        // Drag repository folders in from Finder to open them as tabs
        .dropDestination(for: URL.self) { urls, _ in
            let folders = urls.filter(\.isFileURL)
            guard !folders.isEmpty else { return false }
            repositoryVM.openDropped(folders)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .overlay { if isDropTargeted { DropTargetOverlay() } }
        .alert(
            localized("error.title"),
            isPresented: Binding(
                get: { repositoryVM.errorMessage != nil },
                set: { if !$0 { repositoryVM.errorMessage = nil } }
            )
        ) {
            Button(localized("btn.ok"), role: .cancel) {}
        } message: {
            Text(repositoryVM.errorMessage ?? "")
        }
        .preferredColorScheme(resolvedColorScheme)
        // Open Repo sheet
        .sheet(isPresented: $showingOpenRepo) {
            OpenRepositoryView(viewModel: repositoryVM) {
                showingOpenRepo = false
            }
            .environmentObject(envLanguage)
        }
        // Raw preview sheet
        .sheet(isPresented: $showingRawPreview) {
            if let repo = patternsVM.selectedRepository {
                RawPreviewView(
                    repoPath: repo.path,
                    patterns: patternsVM.patterns
                ) { showingRawPreview = false }
                .environmentObject(envLanguage)
            }
        }
        .sheet(isPresented: $showingAbout) {
            AboutView { showingAbout = false }
                .environmentObject(envLanguage)
        }
        // Add pattern sheet
        .sheet(isPresented: $showingEditor) {
            EditorView(
                viewModel: EditorViewModel(),
                onSave: { patternsVM.addPattern($0) }
            )
            .environmentObject(envLanguage)
        }
        // Edit pattern sheet
        .sheet(item: $patternToEdit) { pattern in
            EditorView(
                viewModel: EditorViewModel(pattern: pattern),
                onSave: { patternsVM.editPattern($0) }
            )
            .environmentObject(envLanguage)
        }
        // Import: merge or replace
        .confirmationDialog(
            localized("dialog.importTitle"),
            isPresented: Binding(
                get: { patternsVM.pendingImport != nil },
                set: { if !$0 { patternsVM.pendingImport = nil } }
            ),
            presenting: patternsVM.pendingImport
        ) { imported in
            Button(localized("btn.merge")) { patternsVM.applyImport(imported, replace: false) }
            Button(localized("btn.replace"), role: .destructive) { patternsVM.applyImport(imported, replace: true) }
            Button(localized("btn.cancel"), role: .cancel) {}
        } message: { imported in
            Text(localized("dialog.importConfirm", args: imported.count))
        }
        // Delete confirmation
        .alert(
            localized("dialog.deleteTitle"),
            isPresented: $showingDeleteConfirm,
            presenting: patternToDelete
        ) { id in
            Button(localized("btn.delete"), role: .destructive) {
                patternsVM.deletePattern(id)
            }
            Button(localized("btn.cancel"), role: .cancel) {}
        } message: { _ in
            Text(localized("dialog.deleteConfirm"))
        }
        .onChange(of: repositoryVM.selectedRepository, initial: true) { _, repository in
            guard let repository else { return }
            patternsVM.loadPatterns(from: repository)
            patternsVM.loadSuggestions(
                from: repositoryVM.recentRepositories.filter { $0.path != repository.path }
            )
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(localized("window.title"))
                    .font(.headline)
                Spacer()
                SettingsDropdownView(
                    languageService: languageService,
                    colorScheme: $colorScheme,
                    onAbout: { showingAbout = true }
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.windowBackgroundColor))
            Divider()
        }
    }

    // MARK: - Pattern Panel (left column)

    private var patternPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            repoInfoBlock
            Divider()
            searchRow
            actionRow
            Divider()
            PatternListView(
                patternsVM: patternsVM,
                onEdit: { patternToEdit = $0 },
                onDelete: {
                    patternToDelete = $0
                    showingDeleteConfirm = true
                }
            )
            Divider()
            statusBar
        }
    }

    private var repoInfoBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let repo = repositoryVM.selectedRepository {
                Text(repo.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(repo.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(localized("status.noRepository"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            if let error = patternsVM.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var searchRow: some View {
        HStack(spacing: 8) {
            // Real button so ⌘F works (keyboardShortcut only fires on buttons/controls)
            Button(action: { isSearchFocused = true }, label: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
            })
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)
            .help(localized("placeholder.search") + " (⌘F)")
            TextField(
                localized("placeholder.search"),
                text: $patternsVM.searchText
            )
            .textFieldStyle(.plain)
            .focused($isSearchFocused)
            .accessibilityLabel(localized("placeholder.search"))
            if !patternsVM.searchText.isEmpty {
                Button(
                    action: { patternsVM.searchText = "" },
                    label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                )
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button(action: { showingEditor = true }, label: {
                Label(localized("btn.add"), systemImage: "plus.circle")
            })
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(patternsVM.selectedRepository == nil)
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityLabel(localized("btn.add"))

            Button(action: { patternsVM.addSection() }, label: {
                Label(localized("btn.addSection"), systemImage: "text.badge.plus")
            })
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(patternsVM.selectedRepository == nil)
            .help(localized("hint.addSection"))

            Button(action: { patternsVM.importPatterns() }, label: {
                Label(localized("btn.import"), systemImage: "arrow.down.doc")
            })
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(patternsVM.selectedRepository == nil)

            Button(action: { patternsVM.exportPatterns() }, label: {
                Label(localized("btn.export"), systemImage: "arrow.up.doc")
            })
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(patternsVM.patterns.isEmpty)

            Spacer()

            Button(action: { patternsVM.restorePreviousVersion() }, label: {
                Label(localized("btn.restore"), systemImage: "arrow.uturn.backward")
            })
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(patternsVM.selectedRepository == nil || patternsVM.isSaving)
            .help(localized("hint.restore"))

            Button(action: { showingRawPreview = true }, label: {
                Label(localized("btn.previewRaw"), systemImage: "eye")
            })
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(patternsVM.selectedRepository == nil)
            .help(localized("btn.previewRaw"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .font(.callout)
    }

    private var statusBar: some View {
        HStack {
            Text(
                localized(
                    "status.patternsCount",
                    args: patternsVM.patternCount,
                    patternsVM.enabledCount
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            if let url = patternsVM.lastExportURL {
                Button("✓ " + localized("status.exported", args: url.lastPathComponent)) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .buttonStyle(.link)
                .font(.caption)
                .help(url.path)
                .task(id: url) {
                    try? await Task.sleep(for: .seconds(5))
                    patternsVM.lastExportURL = nil
                }
            }

            if patternsVM.isSaving {
                ProgressView().scaleEffect(0.6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Computed

    private var resolvedColorScheme: ColorScheme? {
        switch colorScheme {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

struct PatternsView_Previews: PreviewProvider {
    static var previews: some View {
        PatternsView(
            patternsVM: PatternsViewModel(),
            repositoryVM: RepositoryViewModel(),
            languageService: LanguageService.shared
        )
        .environmentObject(LanguageService.shared)
        .frame(width: 800, height: 600)
    }
}

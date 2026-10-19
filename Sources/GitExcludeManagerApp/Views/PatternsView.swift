import SwiftUI
import Shared

/// Main window (v1.1 "Classic Modern", same layout as hosts-manager): repository tabs and the pattern list on the
/// left, a tool window (Clipboard · Suggestions · History · AI Agent · Help, then Appearance · Settings) on the
/// right. Liquid Glass on the control layer only (search, action buttons, side panel; material before macOS 26),
/// Sukhumvit Set for interface text, SF Mono for patterns, a user-chosen appearance / accent / gradient theme.
struct PatternsView: View {
    @ObservedObject var patternsVM: PatternsViewModel
    @ObservedObject var repositoryVM: RepositoryViewModel

    // Observe environment language so view body re-evaluates on language switch
    @EnvironmentObject private var envLanguage: LanguageService

    @AppStorage("ui.accent") private var accent = AccentChoice.system
    @AppStorage("ui.gradient") private var theme = GradientTheme.none
    @AppStorage("ui.appearance") private var appearance = AppearanceChoice.system
    /// Open tool-window panel; "" = hidden. Help on first launch (nothing open yet for the AI Agent to look at).
    @AppStorage("ui.toolPanel") private var toolPanelRaw = ToolPanel.help.rawValue
    @State private var showingEditor = false
    @State private var patternToEdit: GitExcludePattern?
    @State private var showingOpenRepo = false
    @State private var showingRawPreview = false
    @State private var isDropTargeted = false

    private var toolPanel: Binding<ToolPanel?> {
        Binding(get: { ToolPanel(rawValue: toolPanelRaw) }, set: { toolPanelRaw = $0?.rawValue ?? "" })
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                patternsColumn.frame(minWidth: 420)
                ToolWindow(panel: toolPanel, theme: theme, patternsVM: patternsVM,
                           repositoryName: repositoryVM.selectedRepository?.name)
            }
            .navigationTitle(repositoryVM.selectedRepository?.name ?? localized("window.title"))
            .navigationSubtitle(repositoryVM.selectedRepository?.displayPath ?? "")
        }
        .font(.app(13))
        .tint(accent.color)
        .preferredColorScheme(appearance.colorScheme)
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
        .modifier(PatternsSheets(
            patternsVM: patternsVM, repositoryVM: repositoryVM, envLanguage: envLanguage,
            showingEditor: $showingEditor, patternToEdit: $patternToEdit, showingOpenRepo: $showingOpenRepo,
            showingRawPreview: $showingRawPreview
        ))
        .onChange(of: repositoryVM.selectedRepository, initial: true) { _, repository in
            guard let repository else { return patternsVM.closeRepository() }  // last tab closed → Welcome
            patternsVM.loadPatterns(from: repository)
            patternsVM.loadSuggestions(
                from: repositoryVM.recentRepositories.filter { $0.path != repository.path }
            )
        }
    }

    // MARK: - Left column

    private var patternsColumn: some View {
        VStack(spacing: 0) {
            RepositoryTabBar(
                repositoryVM: repositoryVM,
                accent: accent,
                onTabSwitch: { patternsVM.searchText = "" },
                onOpenRepository: { showingOpenRepo = true }
            )
            if repositoryVM.selectedRepository == nil {
                WelcomeView(repositoryVM: repositoryVM) { toolPanelRaw = ToolPanel.help.rawValue }
            } else {
                controls
                if let error = patternsVM.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.app(12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 6)
                }
                PatternListView(patternsVM: patternsVM, onEdit: { patternToEdit = $0 },
                                onAdd: { showingEditor = true })
                statusBar
            }
        }
        .background(Color(.textBackgroundColor))
    }

    /// Control layer: search capsule + action buttons, glass on macOS 26.
    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(localized("placeholder.search"), text: $patternsVM.searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel(localized("placeholder.search"))
                if !patternsVM.searchText.isEmpty {
                    Button { patternsVM.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(localized("btn.clear"))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .glassSurface(cornerRadius: 16)

            HStack(spacing: 8) {
                Button { showingEditor = true } label: { Label(localized("btn.add"), systemImage: "plus") }
                    .glassButton(prominent: true)
                    .keyboardShortcut("n")
                Group {
                    Button(action: patternsVM.addSection) {
                        Label(localized("btn.addSection"), systemImage: "text.badge.plus")
                    }
                    .help(localized("hint.addSection"))
                    Button(action: patternsVM.importPatterns) {
                        Label(localized("btn.import"), systemImage: "square.and.arrow.down")
                    }
                    Button(action: patternsVM.exportPatterns) {
                        Label(localized("btn.export"), systemImage: "square.and.arrow.up")
                    }
                    .disabled(patternsVM.patterns.isEmpty)
                }
                .glassButton()
                Spacer(minLength: 8)
                Button { showingRawPreview = true } label: {
                    Label(localized("btn.previewRaw"), systemImage: "doc.plaintext")
                }
                .glassButton()
                .fixedSize()
            }
            .font(.app(13, .medium))  // button labels don't inherit the root font
            .glassGroup()
        }
        .controlSize(.regular)
        .padding(12)
    }

    private var statusBar: some View {
        HStack {
            Text(localized("status.patternsCount", args: patternsVM.patternCount, patternsVM.enabledCount))
                .font(.app(12))
                .foregroundStyle(.secondary)
            Spacer()
            if let url = patternsVM.lastExportURL {
                Button(localized("status.exported", args: url.lastPathComponent)) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .buttonStyle(.link)
                .font(.app(12))
                .help(url.path)
                .task(id: url) {
                    try? await Task.sleep(for: .seconds(5))
                    patternsVM.lastExportURL = nil
                }
            }
            if patternsVM.isSaving { ProgressView().controlSize(.small) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}

/// The window's sheets and the import dialog, kept out of PatternsView's body.
private struct PatternsSheets: ViewModifier {
    @ObservedObject var patternsVM: PatternsViewModel
    @ObservedObject var repositoryVM: RepositoryViewModel
    let envLanguage: LanguageService
    @Binding var showingEditor: Bool
    @Binding var patternToEdit: GitExcludePattern?
    @Binding var showingOpenRepo: Bool
    @Binding var showingRawPreview: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingOpenRepo) {
                OpenRepositoryView(viewModel: repositoryVM) { showingOpenRepo = false }
                    .environmentObject(envLanguage)
            }
            .sheet(isPresented: $showingRawPreview) {
                if let repo = patternsVM.selectedRepository {
                    RawPreviewView(repoPath: repo.path, patterns: patternsVM.patterns) { showingRawPreview = false }
                        .environmentObject(envLanguage)
                }
            }
            .sheet(isPresented: $showingEditor) {
                EditorView(viewModel: EditorViewModel(), onSave: { patternsVM.addPattern($0) })
                    .environmentObject(envLanguage)
            }
            .sheet(item: $patternToEdit) { pattern in
                EditorView(viewModel: EditorViewModel(pattern: pattern), onSave: { patternsVM.editPattern($0) })
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
    }
}

struct PatternsView_Previews: PreviewProvider {
    static var previews: some View {
        PatternsView(
            patternsVM: PatternsViewModel(),
            repositoryVM: RepositoryViewModel()
        )
        .environmentObject(LanguageService.shared)
        .frame(width: 1100, height: 700)
    }
}

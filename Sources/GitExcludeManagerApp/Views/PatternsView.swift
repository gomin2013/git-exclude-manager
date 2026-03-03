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
    @State private var showingAISettings = false
    @State private var isDropTargeted = false
    @State private var chatTurns: [ChatTurn] = []
    @State private var chatInput = ""
    @State private var isAsking = false
    @State private var chatError: String?
    /// Cached so the body doesn't hit the Keychain on every render; reloaded when the settings sheet closes.
    @State private var aiSettings = AISettings.load()
    @State private var aiModels: [String] = []
    /// Right-column panels can be folded; remembered across launches.
    @AppStorage("ui.suggestionsCollapsed") private var suggestionsCollapsed = false
    @AppStorage("ui.chatCollapsed") private var chatCollapsed = false
    @AppStorage("ui.helpCollapsed") private var helpCollapsed = true  // folded by default: don't squeeze the chat
    @State private var patternToDelete: UUID?
    @State private var colorScheme: SettingsDropdownView.ColorSchemePreference = .system
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            repoTabBar
            HSplitView {
                patternPanel
                    .frame(minWidth: 340)
                VStack(spacing: 0) {
                    suggestionsPanel
                    Divider()
                    chatPanel
                    Divider()
                    helpPanel
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
        .overlay { if isDropTargeted { dropOverlay } }
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
        .sheet(isPresented: $showingAISettings, onDismiss: { aiSettings = AISettings.load() }) {
            AISettingsView { showingAISettings = false }
                .environmentObject(envLanguage)
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

    /// Dashed frame + hint while a Finder folder hovers over the window.
    private var dropOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
            .background(Color.accentColor.opacity(0.08))
            .overlay {
                Label(localized("hint.dropRepository"), systemImage: "folder.badge.plus")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
            }
            .padding(6)
            .allowsHitTesting(false)
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

    // MARK: - Repo Tab Bar

    @ViewBuilder
    private var repoTabBar: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(repositoryVM.openRepositories, id: \.path) { repo in
                        repoTab(repo)
                            // Drag a tab onto another to reorder (payload = repo path)
                            .draggable(repo.path) { repoTab(repo).opacity(0.8) }
                            .dropDestination(for: String.self) { paths, _ in
                                guard let dropped = paths.first else { return false }
                                let path = URL(string: dropped).flatMap { $0.isFileURL ? $0.path : nil } ?? dropped
                                if repositoryVM.openRepositories.contains(where: { $0.path == path }) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        repositoryVM.moveRepository(path: path, onto: repo.path)
                                    }
                                } else {
                                    repositoryVM.openDropped([URL(fileURLWithPath: path)])  // Finder folder dropped on a tab
                                }
                                return true
                            }
                    }
                    // + sits right after the last tab, like a browser
                    Button(
                        action: { showingOpenRepo = true },
                        label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 28, height: 28)
                        }
                    )
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(localized("btn.openRepo"))
                    .accessibilityLabel(localized("btn.openRepo"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.windowBackgroundColor))
            Divider()
        }
    }

    private func repoTab(_ repo: GitRepository) -> some View {
        let isActive = repo.path == repositoryVM.selectedRepository?.path
        let activate = {
            guard !isActive else { return }
            patternsVM.searchText = ""
            repositoryVM.switchTo(repo)
        }
        return HStack(spacing: 6) {
            // Text + tap, not Button: an AppKit-backed Button swallows mouse-drag, so .draggable never fired
            Text(repo.name)
                .font(.callout)
                .fontWeight(isActive ? .semibold : .regular)
                .help(repo.displayPath)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(.default, activate)

            // × only when there is more than one tab (matches .prototype)
            if repositoryVM.openRepositories.count > 1 {
                Button(action: { repositoryVM.closeRepository(path: repo.path) }, label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                })
                .buttonStyle(.plain)
                .accessibilityLabel(localized("btn.close") + " " + repo.name)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(isActive ? Color.accentColor : Color.secondary.opacity(0.12))
        .foregroundStyle(isActive ? Color.white : Color.primary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())  // whole tab (incl. padding) is clickable + draggable
        .onTapGesture(perform: activate)
    }

    // MARK: - Pattern Panel (left column)

    private var patternPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            repoInfoBlock
            Divider()
            searchRow
            actionRow
            Divider()
            patternListContent
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

    @ViewBuilder
    private var patternListContent: some View {
        if patternsVM.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if patternsVM.filteredPatterns.isEmpty {
            Text(localized("message.noPatterns"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(patternsVM.filteredPatterns) { pattern in
                    PatternRow(
                        pattern: pattern,
                        onToggle: { patternsVM.togglePattern(pattern.id) },
                        onEdit: { patternToEdit = pattern },
                        onDelete: {
                            patternToDelete = pattern.id
                            showingDeleteConfirm = true
                        },
                        onRename: { patternsVM.renameSection(pattern.id, to: $0) }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .listRowSeparator(.hidden)
                    // Filtered indices don't map to file order, so reorder only when not searching.
                    .moveDisabled(!patternsVM.searchText.isEmpty || pattern.isGitDefaultHeader)
                }
                .onMove(perform: moveRows)
            }
            .listStyle(.plain)
        }
    }

    private func moveRows(from source: IndexSet, to destination: Int) {
        patternsVM.movePatterns(from: source, to: destination)
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

    // MARK: - Chat Panel (right column)

    // MARK: - Pattern Suggestions (right column, top)

    /// ▸/▾ + title; click folds the panel.
    private func collapseToggle(_ title: String, isCollapsed: Binding<Bool>) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { isCollapsed.wrappedValue.toggle() }
        }, label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isCollapsed.wrappedValue ? 0 : 90))
                    .frame(width: 10)
                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
            }
            .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(localized(isCollapsed.wrappedValue ? "a11y.collapsed" : "a11y.expanded"))
        .accessibilityHint(localized("a11y.toggleHint"))
    }

    /// Patterns the user's other recent repositories have and this one doesn't — one click to add.
    private var suggestionsPanel: some View {
        let suggestions = patternsVM.suggestions
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                collapseToggle(localized("suggest.title"), isCollapsed: $suggestionsCollapsed)
                Spacer()
                if !suggestions.isEmpty {
                    Text("\(suggestions.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if suggestionsCollapsed {
                EmptyView()
            } else if suggestions.isEmpty {
                Text(localized("suggest.empty"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(suggestions) { suggestion in
                            suggestionRow(suggestion)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                // ~38pt per row, capped so chat/help keep the column — unless both are folded
                .frame(maxHeight: chatCollapsed && helpCollapsed
                    ? .infinity : min(CGFloat(suggestions.count) * 38 + 8, 200))
            }
        }
        .background(Color(.windowBackgroundColor))
    }

    private func suggestionRow(_ suggestion: PatternSuggestion) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(suggestion.pattern)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(localized("suggest.from", args: suggestion.repos.joined(separator: ", ")))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .help(suggestion.comment ?? suggestion.pattern)
            Spacer()
            Button(action: { patternsVM.addSuggestion(suggestion) }, label: {
                Image(systemName: "plus.circle.fill")
            })
            .buttonStyle(.borderless)
            .disabled(patternsVM.selectedRepository == nil)
            .help(localized("suggest.add"))
            .accessibilityLabel(localized("suggest.add") + " " + suggestion.pattern)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
    }

    // MARK: - Help (right column, bottom)

    private var helpPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                collapseToggle(localized("menu.help"), isCollapsed: $helpCollapsed)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if !helpCollapsed {
                ScrollView { HelpList() }
                    .frame(maxHeight: .infinity)
            }
        }
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Quick Messages

    private static let quickMessageKeys = [
        "quick.suggest", "quick.explain", "quick.redundant", "quick.exceptOne", "quick.organize"
    ]

    /// One-tap example prompts above the chat input.
    private var quickMessages: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
            ForEach(Self.quickMessageKeys, id: \.self) { key in
                Button(action: {
                    chatInput = localized(key)
                    sendChat()
                }, label: {
                    // plain + custom background: bordered macOS buttons never wrap, which truncated these
                    Text(localized(key))
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                })
                .buttonStyle(.plain)
                .disabled(isAsking || !aiSettings.isConfigured)
                .opacity(isAsking || !aiSettings.isConfigured ? 0.5 : 1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    /// Current model under the "AI Agent" title; click to switch models of the same provider.
    private var modelMenu: some View {
        Menu {
            if aiSettings.provider.needsModel {
                ForEach(aiModels, id: \.self) { model in
                    Button(action: { selectModel(model) }, label: {
                        if model == aiSettings.model {
                            Label(model, systemImage: "checkmark")
                        } else {
                            Text(model)
                        }
                    })
                }
                if aiModels.isEmpty {
                    Text(localized("settings.noModels"))
                }
                Divider()
            }
            Button(localized("settings.title") + "…") { showingAISettings = true }
        } label: {
            Text(modelLabel)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(aiSettings.isConfigured ? Color.primary : Color.orange)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(aiSettings.provider.displayName)
    }

    private var modelLabel: String {
        guard aiSettings.isConfigured else { return localized("ai.notConfigured") }
        return aiSettings.provider.needsModel ? aiSettings.model : aiSettings.provider.displayName
    }

    private func loadAIModels() async {
        let settings = aiSettings
        guard settings.provider.needsModel, !settings.provider.needsAPIKey || !settings.apiKey.isEmpty else {
            aiModels = []
            return
        }
        aiModels = (try? await AIService.listModels(settings.provider, apiKey: settings.apiKey)) ?? []
    }

    private func selectModel(_ model: String) {
        aiSettings.model = model
        aiSettings.save()
    }

    private func chatBubble(_ turn: ChatTurn) -> some View {
        let isUser = turn.role == .user
        return Text(turn.text)
            .font(.callout)
            .textSelection(.enabled)
            .padding(8)
            .background(isUser ? Color.accentColor.opacity(0.85) : Color.secondary.opacity(0.15))
            .foregroundStyle(isUser ? Color.white : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    /// Gives the model the repo's current exclude file so answers are about *this* repository.
    private var chatSystemPrompt: String {
        let repo = repositoryVM.selectedRepository?.name ?? "(none)"
        let file = ExcludeParserService.serialize(patternsVM.patterns)
        let language = envLanguage.currentLanguage == .thai ? "Thai" : "English"
        return """
        You are the assistant inside Git Exclude Manager, a macOS app that edits a repository's \
        .git/info/exclude file (gitignore syntax; ignores that stay local and are never committed). \
        Help the user write and understand ignore patterns. Be concise. Reply in \(language).

        Repository: \(repo)
        Current .git/info/exclude:
        \(file.isEmpty ? "(empty)" : file)
        """
    }

    private func sendChat() {
        let question = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isAsking else { return }
        chatTurns.append(ChatTurn(role: .user, text: question))
        chatInput = ""
        chatError = nil
        isAsking = true
        let turns = chatTurns, system = chatSystemPrompt, settings = aiSettings
        Task {
            do {
                let reply = try await AIService.complete(settings, system: system, turns: turns)
                chatTurns.append(ChatTurn(role: .assistant, text: reply))
            } catch {
                chatError = error.localizedDescription
            }
            isAsking = false
        }
    }

    private var chatPanel: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    collapseToggle(localized("chat.title"), isCollapsed: $chatCollapsed)
                    modelMenu
                        .padding(.leading, 16)  // align under the title, past the chevron
                }
                Spacer()
                Button(action: { showingAISettings = true }, label: {
                    Image(systemName: "gearshape")
                })
                .buttonStyle(.borderless)
                .help(localized("settings.title"))
                .accessibilityLabel(localized("settings.title"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.windowBackgroundColor))
            .task(id: aiSettings.provider.rawValue + aiSettings.apiKey) { await loadAIModels() }

            if !chatCollapsed {
                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized("chat.welcome"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .center)

                        ForEach(Array(chatTurns.enumerated()), id: \.offset) { _, turn in
                            chatBubble(turn)
                        }
                        if isAsking {
                            ProgressView().controlSize(.small).padding(.leading, 6)
                        }
                        if let chatError {
                            Text(chatError).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                        }
                        if !aiSettings.isConfigured {
                            Button(localized("chat.noApiKey")) { showingAISettings = true }
                                .buttonStyle(.link)
                                .font(.caption)
                        }
                    }
                    .padding(10)
                }
                .defaultScrollAnchor(.bottom)
                .frame(maxHeight: .infinity)

                Divider()

                quickMessages

                HStack(spacing: 8) {
                    TextField(localized("chat.placeholder"), text: $chatInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(sendChat)
                        .accessibilityLabel(localized("chat.placeholder"))

                    Button(localized("btn.send"), action: sendChat)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isAsking || chatInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(10)
            }
        }
        .background(Color(.windowBackgroundColor))
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

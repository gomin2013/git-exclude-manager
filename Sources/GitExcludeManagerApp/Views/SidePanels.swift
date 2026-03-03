import SwiftUI
import Shared

// Right-column panels of PatternsView: Pattern Suggestions, AI Agent, Help.
// Each folds with a CollapseToggle; PatternsView owns the folded flags (@AppStorage) and the layout.

/// ▸/▾ + title; click folds the panel.
struct CollapseToggle: View {
    let title: String
    @Binding var isCollapsed: Bool

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { isCollapsed.toggle() }
        }, label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .frame(width: 10)
                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
            }
            .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(localized(isCollapsed ? "a11y.collapsed" : "a11y.expanded"))
        .accessibilityHint(localized("a11y.toggleHint"))
    }
}

// MARK: - Pattern Suggestions

/// Patterns the user's other recent repositories have and this one doesn't — one click to add.
struct SuggestionsPanel: View {
    @ObservedObject var patternsVM: PatternsViewModel
    @Binding var isCollapsed: Bool
    /// True when the panels below are folded: the list may take the whole column.
    let fillsColumn: Bool

    @EnvironmentObject private var languageService: LanguageService

    var body: some View {
        let suggestions = patternsVM.suggestions
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                CollapseToggle(title: localized("suggest.title"), isCollapsed: $isCollapsed)
                Spacer()
                if !suggestions.isEmpty {
                    Text("\(suggestions.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if isCollapsed {
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
                            row(suggestion)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                // ~38pt per row, capped so chat/help keep the column — unless both are folded
                .frame(maxHeight: fillsColumn ? .infinity : min(CGFloat(suggestions.count) * 38 + 8, 200))
            }
        }
        .background(Color(.windowBackgroundColor))
    }

    private func row(_ suggestion: PatternSuggestion) -> some View {
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
}

// MARK: - AI Agent

/// Chat with the configured AI provider about this repository's exclude file.
struct ChatPanel: View {
    @ObservedObject var patternsVM: PatternsViewModel
    let repositoryName: String?
    @Binding var isCollapsed: Bool

    @EnvironmentObject private var languageService: LanguageService
    @State private var turns: [ChatTurn] = []
    @State private var input = ""
    @State private var isAsking = false
    @State private var chatError: String?
    /// Cached so the body doesn't hit the Keychain on every render; reloaded when the settings sheet closes.
    @State private var aiSettings = AISettings.load()
    @State private var models: [String] = []
    @State private var showingSettings = false

    private static let quickMessageKeys = [
        "quick.suggest", "quick.explain", "quick.redundant", "quick.exceptOne", "quick.organize"
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            if !isCollapsed {
                Divider()
                transcript
                Divider()
                quickMessages
                inputRow
            }
        }
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $showingSettings, onDismiss: reloadSettings) {
            AISettingsView { showingSettings = false }
                .environmentObject(languageService)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                CollapseToggle(title: localized("chat.title"), isCollapsed: $isCollapsed)
                modelMenu
                    .padding(.leading, 16)  // align under the title, past the chevron
            }
            Spacer()
            Button(action: { showingSettings = true }, label: {
                Image(systemName: "gearshape")
            })
            .buttonStyle(.borderless)
            .help(localized("settings.title"))
            .accessibilityLabel(localized("settings.title"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.windowBackgroundColor))
        .task(id: aiSettings.provider.rawValue + aiSettings.apiKey) { await loadModels() }
    }

    private var transcript: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(localized("chat.welcome"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .center)

                ForEach(Array(turns.enumerated()), id: \.offset) { _, turn in
                    bubble(turn)
                }
                if isAsking {
                    ProgressView().controlSize(.small).padding(.leading, 6)
                }
                if let chatError {
                    Text(chatError).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                }
                if !aiSettings.isConfigured {
                    Button(localized("chat.noApiKey")) { showingSettings = true }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }
            .padding(10)
        }
        .defaultScrollAnchor(.bottom)
        .frame(maxHeight: .infinity)
    }

    private func bubble(_ turn: ChatTurn) -> some View {
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

    /// One-tap example prompts above the input.
    private var quickMessages: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
            ForEach(Self.quickMessageKeys, id: \.self) { key in
                Button(action: {
                    input = localized(key)
                    send()
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

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField(localized("chat.placeholder"), text: $input)
                .textFieldStyle(.roundedBorder)
                .onSubmit(send)
                .accessibilityLabel(localized("chat.placeholder"))

            Button(localized("btn.send"), action: send)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isAsking || input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(10)
    }

    /// Current model under the "AI Agent" title; click to switch models of the same provider.
    private var modelMenu: some View {
        Menu {
            if aiSettings.provider.needsModel {
                ForEach(models, id: \.self) { model in
                    Button(action: { selectModel(model) }, label: {
                        if model == aiSettings.model {
                            Label(model, systemImage: "checkmark")
                        } else {
                            Text(model)
                        }
                    })
                }
                if models.isEmpty {
                    Text(localized("settings.noModels"))
                }
                Divider()
            }
            Button(localized("settings.title") + "…") { showingSettings = true }
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

    /// Gives the model the repo's current exclude file so answers are about *this* repository.
    private var systemPrompt: String {
        let file = ExcludeParserService.serialize(patternsVM.patterns)
        let language = languageService.currentLanguage == .thai ? "Thai" : "English"
        return """
        You are the assistant inside Git Exclude Manager, a macOS app that edits a repository's \
        .git/info/exclude file (gitignore syntax; ignores that stay local and are never committed). \
        Help the user write and understand ignore patterns. Be concise. Reply in \(language).

        Repository: \(repositoryName ?? "(none)")
        Current .git/info/exclude:
        \(file.isEmpty ? "(empty)" : file)
        """
    }

    private func send() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isAsking else { return }
        turns.append(ChatTurn(role: .user, text: question))
        input = ""
        chatError = nil
        isAsking = true
        let history = turns, system = systemPrompt, settings = aiSettings
        Task {
            do {
                let reply = try await AIService.complete(settings, system: system, turns: history)
                turns.append(ChatTurn(role: .assistant, text: reply))
            } catch {
                chatError = error.localizedDescription
            }
            isAsking = false
        }
    }

    private func loadModels() async {
        let settings = aiSettings
        guard settings.provider.needsModel, !settings.provider.needsAPIKey || !settings.apiKey.isEmpty else {
            models = []
            return
        }
        models = (try? await AIService.listModels(settings.provider, apiKey: settings.apiKey)) ?? []
    }

    private func selectModel(_ model: String) {
        aiSettings.model = model
        aiSettings.save()
    }

    private func reloadSettings() {
        aiSettings = AISettings.load()
    }
}

// MARK: - Help

struct HelpPanel: View {
    @Binding var isCollapsed: Bool

    @EnvironmentObject private var languageService: LanguageService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                CollapseToggle(title: localized("menu.help"), isCollapsed: $isCollapsed)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if !isCollapsed {
                ScrollView { HelpList() }
                    .frame(maxHeight: .infinity)
            }
        }
        .background(Color(.windowBackgroundColor))
    }
}

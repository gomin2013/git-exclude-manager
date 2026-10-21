import SwiftUI
import Shared

/// Chat with the configured AI provider about this repository's exclude file. Same panel as hosts-manager's
/// (keep the two in sync until DevFileKit); differences: the context is the exclude file, and the tool window opens
/// on `ChatIntro` before the first question.
/// Replies stream: a step checklist (attached → waiting → thinking → writing) and the model's thinking show while
/// it works, the answer renders as Markdown as it arrives, and Stop cancels.
struct ChatPanel: View {
    @ObservedObject var patternsVM: PatternsViewModel
    let repositoryName: String?
    @Binding var isCollapsed: Bool
    /// `.clear` when the panel sits on a glass / material surface.
    var panelBackground = Color(.windowBackgroundColor)
    /// Shown alone in a tool window (redesign D): no fold header — the window has its own title — and full height.
    var isToolWindow = false

    /// Where the live reply is. The file is attached the moment the question is sent.
    enum Step: Int, Comparable {
        case attached, waiting, thinking, writing
        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    @EnvironmentObject private var languageService: LanguageService
    @State private var turns: [ChatTurn] = []
    @State private var input = ""
    @State private var chatError: String?
    /// Cached so the body doesn't hit the Keychain on every render; reloaded when the settings sheet closes.
    @State private var aiSettings = AISettings.load()
    @State private var models: [String] = []
    @State private var showingSettings = false
    /// Non-nil while a reply streams (Stop cancels it).
    @State private var reply: Task<Void, Never>?
    @State private var step = Step.waiting
    @State private var startedAt = Date.now
    /// Finished turns whose thinking the user opened.
    @State private var openThinking: Set<Int> = []

    static let quickMessageKeys = [
        "quick.suggest", "quick.explain", "quick.redundant", "quick.exceptOne", "quick.organize"
    ]

    private var isAsking: Bool { reply != nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            if !isCollapsed {
                Divider()
                if isToolWindow && turns.isEmpty {
                    ChatIntro(quickMessageKeys: Self.quickMessageKeys, isConfigured: aiSettings.isConfigured,
                              onAsk: { input = $0; send() }, onSetUp: { showingSettings = true })
                } else {
                    transcript
                    Divider()
                    quickMessages
                }
                inputRow
            }
        }
        .background(panelBackground)
        .sheet(isPresented: $showingSettings, onDismiss: reloadSettings) {
            AISettingsView { showingSettings = false }
                .environmentObject(languageService)
        }
        #if DEBUG
        // `-ask "question"`: send on launch — screenshots of a live reply without synthetic typing
        .task {
            let args = CommandLine.arguments
            // `-ask=question` too: the bundled app opens no window when launched with a bare value argument
            let question = args.first { $0.hasPrefix("-ask=") }.map { String($0.dropFirst(5)) }
                ?? args.firstIndex(of: "-ask").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
            if let question, turns.isEmpty {
                input = question
                send()
            }
        }
        #endif
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if !isToolWindow { CollapseToggle(title: localized("chat.title"), isCollapsed: $isCollapsed) }
                modelMenu
                    .padding(.leading, isToolWindow ? 0 : 16)  // align under the title, past the chevron
            }
            Spacer()
            Button(action: { showingSettings = true }, label: { Image(systemName: "gearshape") })
                .buttonStyle(.borderless)
                .help(localized("settings.title"))
                .accessibilityLabel(localized("settings.title"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .task(id: aiSettings.provider.rawValue + aiSettings.apiKey) { await loadModels() }
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(localized("chat.welcome"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .center)

                ForEach(Array(turns.enumerated()), id: \.offset) { index, turn in
                    if turn.role == .user { question(turn.text) } else { answer(turn, index: index) }
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

    private func question(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .textSelection(.enabled)
            .padding(8)
            .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func answer(_ turn: ChatTurn, index: Int) -> some View {
        let isLive = isAsking && index == turns.count - 1
        return VStack(alignment: .leading, spacing: 8) {
            if isLive { steps(showingThinking: !turn.thinking.isEmpty) }
            if !turn.thinking.isEmpty {
                // Open while the model is still thinking; folded once the answer starts
                DisclosureGroup(isExpanded: Binding(
                    get: { openThinking.contains(index) || (isLive && turn.text.isEmpty) },
                    set: { if $0 { openThinking.insert(index) } else { openThinking.remove(index) } }
                )) {
                    Text(turn.thinking)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label(turn.seconds.map { localized("chat.thought", args: $0) } ?? localized("chat.step.thinking"),
                          systemImage: "brain")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            if !turn.text.isEmpty { MarkdownText(text: turn.text).font(.callout) }
            if let seconds = turn.seconds {
                Text(localized("chat.seconds", args: seconds)).font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    /// ✓ done · spinner now · ○ next, with seconds on the current step.
    private func steps(showingThinking: Bool) -> some View {
        let thinking: [Step] = showingThinking || step == .thinking ? [.thinking] : []
        let shown: [Step] = [.attached, .waiting] + thinking + [.writing]
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(shown, id: \.self) { item in
                HStack(spacing: 6) {
                    Group {
                        if item < step {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                        } else if item == step {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "circle").foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 14)
                    Text(label(item)).foregroundStyle(item == step ? .primary : .secondary)
                    if item == step {
                        TimelineView(.periodic(from: startedAt, by: 1)) { context in
                            Text(localized("chat.seconds", args: Int(context.date.timeIntervalSince(startedAt))))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
    }

    private func label(_ item: Step) -> String {
        switch item {
        case .attached:
            let lines = patternsVM.patterns.reduce(0) { $0 + $1.linesInFile.count }
            return localized("chat.step.attached", args: lines)
        case .waiting: return localized("chat.step.waiting", args: modelLabel)
        case .thinking: return localized("chat.step.thinking")
        case .writing: return localized("chat.step.writing")
        }
    }

    // MARK: - Input

    /// One-tap example prompts above the input.
    private var quickMessages: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
            ForEach(Self.quickMessageKeys, id: \.self) { key in
                Button(action: {
                    input = localized(key)
                    send()
                }, label: {
                    // plain + custom background: bordered macOS buttons never wrap
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

            if isAsking {
                Button(localized("btn.stop")) { reply?.cancel() }
                    .controlSize(.small)
            } else {
                Button(localized("btn.send"), action: send)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
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
    static func systemPrompt(repository: String?, excludeFile: String, language: LanguageService.Language) -> String {
        """
        You are the assistant inside Git Exclude Manager, a macOS app that edits a repository's \
        .git/info/exclude file (gitignore syntax; ignores that stay local and are never committed). \
        Help the user write and understand ignore patterns. Be concise. \
        Reply in \(language.englishName).

        Repository: \(repository ?? "(none)")
        Current .git/info/exclude:
        \(excludeFile.isEmpty ? "(empty)" : excludeFile)
        """
    }

    // MARK: - Sending

    private func send() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isAsking else { return }
        turns.append(ChatTurn(role: .user, text: question))
        input = ""
        chatError = nil
        // History = questions and answers only; streamed thinking stays on screen and is never sent back
        let history = turns.map { ChatTurn(role: $0.role, text: $0.text) }, settings = aiSettings
        let system = Self.systemPrompt(repository: repositoryName,
                                       excludeFile: ExcludeParserService.serialize(patternsVM.patterns),
                                       language: languageService.currentLanguage)
        turns.append(ChatTurn(role: .assistant, text: ""))
        let index = turns.count - 1
        startedAt = .now
        step = .waiting
        reply = Task {
            do {
                for try await event in AIService.stream(settings, system: system, turns: history) {
                    switch event {
                    case .thinking(let chunk):
                        step = .thinking
                        turns[index].thinking += chunk
                    case .text(let chunk):
                        step = .writing
                        turns[index].text += chunk
                    }
                }
            } catch is CancellationError {
                // Stop: keep whatever arrived
            } catch let error as URLError where error.code == .cancelled {
                // Stop during the request
            } catch {
                chatError = error.localizedDescription
            }
            turns[index].seconds = Int(Date.now.timeIntervalSince(startedAt).rounded())
            if turns[index].text.isEmpty && turns[index].thinking.isEmpty { turns.remove(at: index) }
            reply = nil
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

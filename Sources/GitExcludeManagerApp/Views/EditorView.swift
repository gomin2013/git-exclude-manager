import SwiftUI
import Shared

/// Editor view for adding/editing a pattern
/// Matches .prototype editorDialog — with ✨ Generate Comment button
struct EditorView: View {
    @ObservedObject var viewModel: EditorViewModel
    var onSave: (GitExcludePattern) -> Void = { _ in }
    var onCancel: () -> Void = {}

    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var isGeneratingComment = false

    enum Field { case pattern, comment }

    // Predefined comment suggestions (mirrors shared.js suggestions)
    private static let commentSuggestions: [String: String] = [
        "*.log": "Log files", "*.tmp": "Temporary files", "*.bak": "Backup files",
        "node_modules": "NPM dependencies", "node_modules/": "NPM dependencies",
        ".env": "Environment variables", ".env.local": "Local environment overrides",
        ".venv": "Python virtual environment", "venv/": "Python virtual environment",
        "build": "Build output", "build/": "Build output",
        "dist": "Distribution files", "dist/": "Distribution files",
        ".DS_Store": "macOS system files", "Thumbs.db": "Windows thumbnail cache",
        ".idea": "IDE configuration", ".vscode": "VS Code settings",
        "*.swp": "Vim swap files", ".gradle": "Gradle build directory",
        ".m2": "Maven dependencies cache"
    ]

    var body: some View {
        let isEditing = viewModel.isEditing
        return VStack(spacing: 16) {
            Text(isEditing
                 ? localized("window.editorTitle")
                 : localized("window.addTitle"))
                .font(.headline)

            // Pattern input
            VStack(alignment: .leading, spacing: 6) {
                Label(localized("label.pattern"), systemImage: "text.line.last")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(localized("placeholder.pattern"), text: $viewModel.patternText)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .pattern)
                    .onSubmit { focusedField = .comment }
            }

            // ✨ Generate Comment button — visible only when pattern non-empty
            if !viewModel.patternText.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: generateComment) {
                    if isGeneratingComment {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.75)
                            Text(localized("label.aiGenerating"))
                        }
                    } else {
                        Text(localized("btn.generateComment"))
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.bordered)
                .disabled(isGeneratingComment)
                .help(localized("hint.generateComment"))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Comment input + hint
            VStack(alignment: .leading, spacing: 6) {
                Label(localized("label.comment"), systemImage: "bubble.left")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(localized("placeholder.comment"), text: $viewModel.commentText)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .comment)
                    .onSubmit { handleSave() }

                // Hint — shown only when pattern is empty
                if viewModel.patternText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(localized("hint.generateCommentField"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: viewModel.patternText.isEmpty)

            // Validation error
            if let error = viewModel.validationError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                        .accessibilityHidden(true)
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                .padding(.vertical, 8).padding(.horizontal, 10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }

            // Action buttons — Cancel on left, Save on right
            HStack(spacing: 12) {
                Button(action: handleCancel) {
                    Text(localized("btn.cancel"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])

                Button(action: handleSave) {
                    Text(localized("btn.save"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isValid)
                .keyboardShortcut(.return, modifiers: .command)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: 400)
        .animation(.easeInOut(duration: 0.15), value: viewModel.patternText.isEmpty)
        .onAppear { focusedField = .pattern }
    }

    // MARK: - Private Methods

    private func handleSave() {
        if let pattern = viewModel.createPattern() {
            onSave(pattern)
            dismiss()
        }
    }

    private func handleCancel() {
        onCancel()
        dismiss()
    }

    private func generateComment() {
        let pattern = viewModel.patternText.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty else { return }
        isGeneratingComment = true
        let settings = AISettings.load()
        if settings.isConfigured {
            let language = languageService.currentLanguage == .thai ? "Thai" : "English"
            let system = """
            Write one short comment (at most 10 words) saying what the given gitignore pattern excludes. \
            Reply with the comment text only, in \(language): no quotes, no leading #.
            """
            Task {
                do {
                    let reply = try await AIService.complete(
                        settings, system: system, turns: [ChatTurn(role: .user, text: pattern)]
                    )
                    applyGenerated(reply.trimmingCharacters(in: CharacterSet(charactersIn: "#\"' \n")))
                } catch {
                    viewModel.validationError = error.localizedDescription
                }
                isGeneratingComment = false
            }
            return
        }
        // Not configured: built-in suggestions (mirrors prototype 600–1000ms delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            let generated = Self.commentSuggestions[pattern]
                ?? Self.commentSuggestions[pattern + "/"]
                ?? "Exclude \(pattern) files from version control"
            applyGenerated(generated)
            isGeneratingComment = false
        }
    }

    private func applyGenerated(_ generated: String) {
        if viewModel.commentText.trimmingCharacters(in: .whitespaces).isEmpty {
            viewModel.commentText = generated
        } else {
            viewModel.commentText = generated + " (" + viewModel.commentText + ")"
        }
    }
}

struct EditorView_Previews: PreviewProvider {
    static var previews: some View {
        EditorView(viewModel: EditorViewModel())
            .environmentObject(LanguageService.shared)
    }
}

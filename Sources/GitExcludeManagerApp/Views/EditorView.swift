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

    /// Same layout as hosts-manager's EditorSheet: title, a labelled form, Generate Comment under the comment field,
    /// Cancel / Save bottom-right (Return saves, Esc cancels).
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized(viewModel.isEditing ? "window.editorTitle" : "window.addTitle")).font(.headline)

            Form {
                TextField(localized("label.pattern"), text: $viewModel.patternText,
                          prompt: Text(localized("placeholder.pattern")))
                    .font(.system(.body, design: .monospaced))
                    .focused($focusedField, equals: .pattern)
                if let error = viewModel.validationError { errorText(error) }

                TextField(localized("label.comment"), text: $viewModel.commentText,
                          prompt: Text(localized("placeholder.comment")))
                    .focused($focusedField, equals: .comment)
                HStack(spacing: 6) {
                    Button(action: generateComment) {
                        Label(localized("btn.generateComment"), systemImage: "sparkles")
                    }
                    .controlSize(.small)
                    .disabled(isGeneratingComment || viewModel.patternText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .help(localized("hint.generateComment"))
                    if isGeneratingComment { ProgressView().controlSize(.small) }
                }
            }

            HStack {
                Spacer()
                Button(localized("btn.cancel"), action: handleCancel)
                    .keyboardShortcut(.cancelAction)
                Button(localized("btn.save"), action: handleSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.isValid)
            }
        }
        .padding(18)
        .frame(width: 420)
        .onAppear { focusedField = .pattern }
    }

    private func errorText(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .symbolRenderingMode(.multicolor)
            .font(.caption)
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
            let language = languageService.currentLanguage.englishName
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

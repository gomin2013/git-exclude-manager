import SwiftUI
import Shared

/// Single row in the patterns list — renders a pattern, a section heading, or a comment block
struct PatternRow: View {
    let pattern: GitExcludePattern
    var onToggle: () -> Void = {}
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}
    var onRename: (String) -> Void = { _ in }

    @EnvironmentObject private var languageService: LanguageService

    var body: some View {
        switch pattern.kind {
        case .pattern: patternBody
        case .section: SectionRow(title: pattern.pattern, onRename: onRename, onDelete: onDelete)
        case .comment: commentBody
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Image(systemName: "trash")
                .foregroundColor(.red)
        }
        .buttonStyle(.borderless)
        .help(localized("menu.delete"))
        .accessibilityLabel(localized("menu.delete") + " " + accessibilityName)
    }

    /// What VoiceOver calls this row's item in "Edit …" / "Delete …" (25 identical "Edit" buttons are useless).
    private var accessibilityName: String {
        switch pattern.kind {
        case .pattern: return pattern.pattern
        case .section: return pattern.pattern.isEmpty ? localized("btn.addSection") : pattern.pattern
        case .comment: return pattern.pattern.components(separatedBy: "\n").first ?? ""
        }
    }

    /// Verbatim comment lines (e.g. git's default header) — read-only, but draggable and deletable.
    private var commentBody: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(pattern.pattern)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !pattern.isGitDefaultHeader {
                deleteButton
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
    }

    private var patternBody: some View {
        HStack(spacing: 12) {
            // Toggle button
            Button(action: onToggle) {
                Image(systemName: pattern.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(pattern.isEnabled ? .green : .gray)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                (pattern.isEnabled ? localized("label.enabled") : localized("label.disabled")) + ": " + pattern.pattern
            )

            // Pattern text
            VStack(alignment: .leading, spacing: 2) {
                Text(pattern.displayText)
                    .font(.body)
                    .strikethrough(!pattern.isEnabled)
                    .foregroundColor(pattern.isEnabled ? .primary : .secondary)

                if let comment = pattern.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Row actions
            HStack(spacing: 10) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .help(localized("menu.edit"))
                .accessibilityLabel(localized("menu.edit") + " " + pattern.pattern)

                deleteButton
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(6)
    }
}

/// Section break: a blank line in the file, with an optional `# heading` the user can type inline.
private struct SectionRow: View {
    let title: String
    var onRename: (String) -> Void
    var onDelete: () -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .help(localized("hint.dragSection"))
                .accessibilityHidden(true)
            TextField(localized("section.placeholder"), text: $text)
                .textFieldStyle(.plain)
                .font(.headline)
                .focused($isFocused)
                .onSubmit { onRename(text) }
                .onChange(of: isFocused) { _, focused in if !focused { onRename(text) } }
                .fixedSize()
                .accessibilityLabel(localized("section.placeholder"))
            VStack { Divider() }
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash").foregroundColor(.red)
            }
            .buttonStyle(.borderless)
            .help(localized("menu.delete"))
            .accessibilityLabel(localized("menu.delete") + " " + (title.isEmpty ? localized("btn.addSection") : title))
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
        .padding(.horizontal, 12)
        .onAppear { text = title }
        .onChange(of: title) { _, newTitle in text = newTitle }
    }
}

struct PatternRow_Previews: PreviewProvider {
    static var previews: some View {
        let pattern = GitExcludePattern(
            pattern: "*.log",
            isEnabled: true,
            comment: "Log files"
        )
        return PatternRow(pattern: pattern)
            .environmentObject(LanguageService.shared)
            .padding()
            .frame(width: 320)
    }
}

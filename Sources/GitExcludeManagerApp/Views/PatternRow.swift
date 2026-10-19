import SwiftUI
import Shared

/// Single row in the patterns list — a pattern, a section heading, or a comment block. No cards: edit / delete are
/// always shown (keyboard: Return edits, ⌫ deletes, Space toggles — see PatternListView). Not on hover: rows scrolling
/// under a still pointer didn't get hover-exit, so buttons stuck on and the list stuttered.
struct PatternRow: View {
    let pattern: GitExcludePattern
    var onToggle: () -> Void = {}
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}
    var onRename: (String) -> Void = { _ in }
    /// Section rows: heading shown as a focused text field (see `PatternsViewModel.editingSectionID`).
    var isEditingSection = false
    var onEndEditing: () -> Void = {}

    @EnvironmentObject private var languageService: LanguageService
    @State private var headerExpanded = false

    var body: some View {
        Group {
            switch pattern.kind {
            case .pattern: patternBody
            case .section:
                SectionRow(title: pattern.pattern, isEditing: isEditingSection,
                           onRename: onRename, onEndEditing: onEndEditing, onDelete: onDelete)
            case .comment: commentBody
            }
        }
    }

    private var deleteButton: some View {
        Button(action: onDelete) { Image(systemName: "trash") }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
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

    /// Verbatim comment lines; git's default header folds away (read-only, pinned first).
    @ViewBuilder
    private var commentBody: some View {
        if pattern.isGitDefaultHeader {
            DisclosureGroup(isExpanded: $headerExpanded) {
                Text(pattern.pattern).font(.data(12)).foregroundStyle(.secondary).textSelection(.enabled)
            } label: {
                Text(localized("label.gitHeader")).font(.app(12)).foregroundStyle(.secondary)
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                Text(pattern.pattern)
                    .font(.data(12))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                deleteButton
            }
        }
    }

    private var patternBody: some View {
        HStack(spacing: 12) {
            Toggle(pattern.pattern, isOn: Binding(get: { pattern.isEnabled }, set: { _ in onToggle() }))
                .toggleStyle(.checkbox)
                .labelsHidden()
            VStack(alignment: .leading, spacing: 1) {
                Text(pattern.displayText).font(.data()).lineLimit(1).truncationMode(.middle)
                if let comment = pattern.comment, !comment.isEmpty {
                    Text(comment).font(.app(12)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 12) {
                Button(action: onEdit) { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help(localized("menu.edit"))
                    .accessibilityLabel(localized("menu.edit") + " " + pattern.pattern)
                deleteButton
            }
        }
        .foregroundStyle(pattern.isEnabled ? .primary : .secondary)
        .padding(.vertical, 3)
    }
}

/// Section break: a blank line in the file, with an optional `# heading`.
/// The heading is plain text; it turns into a focused field while editing (new section, double-click, Return) —
/// an always-visible TextField never gets focus inside `List(selection:)`, which looked like a frozen row.
private struct SectionRow: View {
    let title: String
    let isEditing: Bool
    var onRename: (String) -> Void
    var onEndEditing: () -> Void
    var onDelete: () -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Capsule().fill(.tint).frame(width: 4, height: 14).accessibilityHidden(true)
            if isEditing {
                TextField(localized("section.placeholder"), text: $text)
                    .textFieldStyle(.plain)
                    .font(.app(13, .semibold))
                    .focused($isFocused)
                    .onAppear { isFocused = true }
                    .onSubmit(commit)
                    .onChange(of: isFocused) { _, focused in if !focused { commit() } }
                    .onExitCommand {
                        text = title  // Esc: keep the old heading
                        onEndEditing()
                    }
                    .frame(maxWidth: 320)
                    .accessibilityLabel(localized("section.placeholder"))
            } else {
                Text(title.isEmpty ? localized("section.placeholder") : title)
                    .font(.app(13, .semibold))
                    .foregroundStyle(title.isEmpty ? .secondary : .primary)
                    .help(localized("hint.renameSection"))
            }
            Spacer(minLength: 8)
            if !isEditing {
                Button(action: onDelete) { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help(localized("menu.delete"))
                    .accessibilityLabel(
                        localized("menu.delete") + " " + (title.isEmpty ? localized("btn.addSection") : title)
                    )
            }
        }
        .padding(.top, 12)
        .onAppear { text = title }
        .onChange(of: title) { _, newTitle in text = newTitle }
    }

    private func commit() {
        guard isEditing else { return }  // Return already committed; this is the focus loss that follows
        onRename(text)
        onEndEditing()
    }
}

struct PatternRow_Previews: PreviewProvider {
    static var previews: some View {
        PatternRow(pattern: GitExcludePattern(pattern: "*.log", isEnabled: true, comment: "Log files"))
            .environmentObject(LanguageService.shared)
            .padding()
            .frame(width: 320)
    }
}

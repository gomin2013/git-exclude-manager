import SwiftUI
import Shared

// Right-column panels of PatternsView: Pattern Suggestions and Help (AI Agent: ChatPanel.swift).
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
    /// `.clear` when the panel sits on a glass / material surface (redesign D).
    var panelBackground = Color(.windowBackgroundColor)
    /// Shown alone in a tool window (redesign D): no fold header — the window has its own title — and full height.
    var isToolWindow = false

    @EnvironmentObject private var languageService: LanguageService

    var body: some View {
        let suggestions = patternsVM.suggestions
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if !isToolWindow { CollapseToggle(title: localized("suggest.title"), isCollapsed: $isCollapsed) }
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
                .frame(maxHeight: fillsColumn || isToolWindow
                       ? .infinity : min(CGFloat(suggestions.count) * 38 + 8, 200))
            }
        }
        .background(panelBackground)
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

// MARK: - Help

struct HelpPanel: View {
    @Binding var isCollapsed: Bool
    /// `.clear` when the panel sits on a glass / material surface (redesign D).
    var panelBackground = Color(.windowBackgroundColor)
    /// Shown alone in a tool window (redesign D): no fold header — the window has its own title — and full height.
    var isToolWindow = false

    @EnvironmentObject private var languageService: LanguageService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isToolWindow {
                HStack {
                    CollapseToggle(title: localized("menu.help"), isCollapsed: $isCollapsed)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            if !isCollapsed {
                ScrollView { HelpList() }
                    .frame(maxHeight: .infinity)
            }
        }
        .background(panelBackground)
    }
}

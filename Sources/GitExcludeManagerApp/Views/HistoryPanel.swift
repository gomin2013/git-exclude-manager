import SwiftUI
import Shared

/// Photoshop-style History: pinned snapshots on top (the file as opened is pinned for you), then the last
/// `EditHistory.limit` states oldest → newest. Click a state to go back to it; states after it dim until the next
/// edit replaces them. Replaces the one-step "Restore Previous" button.
struct HistoryPanel: View {
    @ObservedObject var patternsVM: PatternsViewModel

    @EnvironmentObject private var languageService: LanguageService

    var body: some View {
        let history = patternsVM.history
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if !history.pinned.isEmpty {
                        header(localized("history.pinned"), systemImage: "pin")
                        ForEach(history.pinned) { state in
                            row(state, isCurrent: false, isAhead: false,
                                remove: { patternsVM.history.unpin(state.id) },
                                action: { patternsVM.restoreSnapshot(state.id) })
                        }
                        Divider().padding(.vertical, 6)
                    }
                    header(localized("history.recent"), systemImage: "clock.arrow.circlepath")
                    ForEach(history.states) { state in
                        let isCurrent = state.id == history.currentState?.id
                        row(state, isCurrent: isCurrent, isAhead: history.isAhead(state.id),
                            remove: isCurrent ? nil : { patternsVM.history.remove(state.id) },
                            action: { patternsVM.goToHistory(state.id) })
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            // Top-aligned: at most `EditHistory.limit` recent states + pins; a bottom anchor left a big gap above
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    if let id = history.currentState?.id, !history.isPinned(id) { patternsVM.history.togglePin(id) }
                } label: {
                    Label(localized("history.pinCurrent"), systemImage: "pin")
                }
                .disabled(history.currentState.map { history.isPinned($0.id) } ?? true)
                Text(localized("history.hint")).font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .frame(maxHeight: .infinity)
    }

    private func header(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
    }

    /// `remove` is nil for the current state (it can't be removed); otherwise a trash button shows.
    private func row(_ state: HistoryState, isCurrent: Bool, isAhead: Bool, remove: (() -> Void)?,
                     action: @escaping () -> Void) -> some View {
        let isPinned = patternsVM.history.isPinned(state.id)
        return HStack(spacing: 8) {
            Image(systemName: isCurrent ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .accessibilityHidden(true)
            Text(state.label).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 4)
            Button { patternsVM.history.togglePin(state.id) } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
            }
            .buttonStyle(.borderless)
            // Shown on every row, so an unpinned pin stays faint; a pinned one keeps the accent colour
            .foregroundStyle(isPinned ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            .help(localized(isPinned ? "history.unpin" : "history.pin"))
            .accessibilityLabel(localized(isPinned ? "history.unpin" : "history.pin"))
            if let remove {
                Button(action: remove) { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help(localized("history.remove"))
                    .accessibilityLabel(localized("history.remove"))
            }
            Text(state.date, style: .time).font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(isCurrent ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 6))
        .opacity(isAhead ? 0.45 : 1)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { action() }
        .accessibilityAction(named: localized("history.remove")) { remove?() }
        .contextMenu {
            if let remove {
                Button(localized("history.remove"), role: .destructive, action: remove)
            }
        }
    }
}

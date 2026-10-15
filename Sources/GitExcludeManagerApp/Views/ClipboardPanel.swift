import SwiftUI
import Shared

/// Patterns collected with ⌘C (from any repository), ready to paste into the current one.
struct ClipboardPanel: View {
    @ObservedObject var patternsVM: PatternsViewModel
    @Binding var isCollapsed: Bool

    @EnvironmentObject private var languageService: LanguageService

    private var canPaste: Bool { patternsVM.selectedRepository != nil }

    var body: some View {
        let items = patternsVM.clipboard
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                CollapseToggle(title: localized("clipboard.title"), isCollapsed: $isCollapsed)
                Spacer()
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(action: { patternsVM.paste(items) }, label: {
                        Image(systemName: "doc.on.clipboard")
                    })
                    .buttonStyle(.borderless)
                    .disabled(!canPaste)
                    .help(localized("clipboard.pasteAll"))
                    .accessibilityLabel(localized("clipboard.pasteAll"))
                    Button(action: patternsVM.clearClipboard, label: {
                        Image(systemName: "trash")
                    })
                    .buttonStyle(.borderless)
                    .help(localized("clipboard.clear"))
                    .accessibilityLabel(localized("clipboard.clear"))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if isCollapsed {
                EmptyView()
            } else if items.isEmpty {
                Text(localized("clipboard.empty"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(items) { item in row(item) }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: min(CGFloat(items.count) * 38 + 8, 160))
            }
        }
        .background(Color(.windowBackgroundColor))
    }

    private func row(_ item: ClipboardItem) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.pattern.pattern)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(localized("suggest.from", args: item.repo))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .help(item.pattern.comment ?? item.pattern.pattern)
            Spacer()
            Button(action: { patternsVM.paste([item]) }, label: {
                Image(systemName: "plus.circle.fill")
            })
            .buttonStyle(.borderless)
            .disabled(!canPaste)
            .help(localized("clipboard.paste"))
            .accessibilityLabel(localized("clipboard.paste") + " " + item.pattern.pattern)
            Button(action: { patternsVM.removeFromClipboard(item.id) }, label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            })
            .buttonStyle(.borderless)
            .help(localized("clipboard.remove"))
            .accessibilityLabel(localized("clipboard.remove") + " " + item.pattern.pattern)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
    }
}

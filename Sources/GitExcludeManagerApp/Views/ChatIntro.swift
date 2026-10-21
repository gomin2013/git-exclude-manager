import SwiftUI

/// What the AI Agent shows before the first question (tool-window mode): what it's for, that the exclude file goes
/// along with each question, and a few one-click questions — like the JetBrains AI Assistant start page.
struct ChatIntro: View {
    let quickMessageKeys: [String]
    let isConfigured: Bool
    var onAsk: (String) -> Void
    var onSetUp: () -> Void

    @EnvironmentObject private var languageService: LanguageService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.title)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text(localized("chat.title")).font(.title2.bold())
                }
                Text(localized("chat.intro"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if isConfigured {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localized("chat.tryAsking")).font(.headline).padding(.bottom, 6)
                        ForEach(quickMessageKeys, id: \.self) { row($0) }
                    }
                } else {
                    Button(localized("chat.setUp"), action: onSetUp)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)
    }

    private func row(_ key: String) -> some View {
        Button { onAsk(localized(key)) } label: {
            HStack(spacing: 10) {
                Image(systemName: Self.icon(key))
                    .foregroundStyle(.tint)
                    .frame(width: 18)
                    .accessibilityHidden(true)
                Text(localized(key))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static func icon(_ key: String) -> String {
        switch key {
        case "quick.suggest": "lightbulb"
        case "quick.explain": "text.magnifyingglass"
        case "quick.redundant": "square.on.square"
        case "quick.exceptOne": "folder.badge.minus"
        case "quick.organize": "list.bullet.indent"
        default: "bubble.left"
        }
    }
}

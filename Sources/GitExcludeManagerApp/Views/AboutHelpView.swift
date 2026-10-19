import SwiftUI

/// Shown in the About panel of the tool window (Settings is split into Language / About for now).
struct AboutView: View {
    @EnvironmentObject private var languageService: LanguageService

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 12) {
            // The bundle's AppIcon (red panda); falls back to the generic app icon under `swift run`
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)
            Text("Git Exclude Manager").font(.title2.bold())
            Text(localized("about.version", args: version))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(localized("about.desc"))
                .multilineTextAlignment(.center)
            Text(localized("about.credit"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

/// Help topics, shown in the right-column Help panel (was a sheet behind the Settings menu).
struct HelpList: View {
    @EnvironmentObject private var languageService: LanguageService

    /// Order follows the workflow: build content (toolbar Add → Section), edit rows, whole-file actions, then helpers.
    private let items: [(icon: String, key: String)] = [
        ("plus.circle", "help.add"),
        ("text.badge.plus", "help.sections"),
        ("checkmark.circle", "help.toggle"),
        ("line.3.horizontal", "help.reorder"),
        ("arrow.down.doc", "help.import"),
        ("clock.arrow.circlepath", "help.history"),
        ("eye", "help.preview"),
        ("square.on.square", "help.tabs"),
        ("doc.on.clipboard", "help.clipboard"),
        ("lightbulb", "help.suggestions"),
        ("sparkles", "help.ai")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(items, id: \.key) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: item.icon)
                        .frame(width: 18)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localized(item.key + ".title")).font(.callout.bold())
                        Text(localized(item.key + ".desc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }
}

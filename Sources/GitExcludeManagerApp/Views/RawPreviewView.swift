import SwiftUI
import AppKit
import Shared

/// Modal showing raw .git/info/exclude content with Copy button
/// Matches .prototype rawPreviewDialog
struct RawPreviewView: View {
    let repoPath: String
    let patterns: [GitExcludePattern]
    var onDismiss: () -> Void = {}

    @EnvironmentObject private var languageService: LanguageService
    @State private var copied = false

    private var excludePath: String {
        (repoPath as NSString).abbreviatingWithTildeInPath + "/.git/info/exclude"
    }

    private var rawContent: String {
        ExcludeParserService.serialize(patterns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header
            HStack {
                Text(localized("raw.title"))
                    .font(.headline)
                Spacer()
                // Icon button, same circle as CloseButton; flips to a green ✓ for 1.5 s after copying
                Button(action: copyContent) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(copied ? Color.green : Color.secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.secondary.opacity(0.15)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .help(localized(copied ? "raw.copied" : "btn.copy") + " (⇧⌘C)")
                .accessibilityLabel(localized(copied ? "raw.copied" : "btn.copy"))

                CloseButton(action: onDismiss)
            }
            .padding(14)

            Divider()

            // MARK: - Path
            Text(excludePath)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.controlBackgroundColor))

            // MARK: - Content
            ScrollView {
                Text(rawContent)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 280)
            .background(Color(.textBackgroundColor))
        }
        .frame(width: 520)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Private

    private func copyContent() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(rawContent, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}

struct RawPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        RawPreviewView(
            repoPath: "/Users/demo/MyProject",
            patterns: [
                GitExcludePattern(pattern: "*.log", isEnabled: true, comment: "Log files"),
                GitExcludePattern(pattern: "node_modules", isEnabled: true, comment: "Dependencies"),
                GitExcludePattern(pattern: ".env", isEnabled: false, comment: nil)
            ]
        )
        .environmentObject(LanguageService.shared)
    }
}

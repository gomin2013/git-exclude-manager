import SwiftUI
import Shared

/// Single row in the patterns list
struct PatternRow: View {
    let pattern: GitExcludePattern
    var onToggle: () -> Void = {}
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            // Toggle button
            Button(action: onToggle) {
                Image(systemName: pattern.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(pattern.isEnabled ? .green : .gray)
            }
            .buttonStyle(.plain)
            .disabled(true) // Phase 1: Static mockup

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

            // Menu button
            Menu {
                Button(action: onEdit) {
                    Label(NSLocalizedString("menu.edit", comment: ""), systemImage: "pencil")
                }
                Button(action: onDelete) {
                    Label(NSLocalizedString("menu.delete", comment: ""), systemImage: "trash")
                        .foregroundColor(.red)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
            .disabled(true) // Phase 1: Static mockup
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(6)
    }
}

#Preview {
    let pattern = GitExcludePattern(
        pattern: "*.log",
        isEnabled: true,
        comment: "Log files"
    )

    PatternRow(pattern: pattern)
        .padding()
        .frame(width: 320)
}

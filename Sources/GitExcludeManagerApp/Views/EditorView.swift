import SwiftUI
import Shared

/// Editor view for adding/editing a pattern
struct EditorView: View {
    @ObservedObject var viewModel: EditorViewModel
    var onSave: (GitExcludePattern) -> Void = { _ in }
    var onCancel: () -> Void = {}

    @FocusState private var focusedField: Field?

    enum Field {
        case pattern
        case comment
    }

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text(NSLocalizedString("window.editorTitle", comment: ""))
                .font(.headline)

            // Pattern input
            VStack(alignment: .leading, spacing: 6) {
                Label(
                    NSLocalizedString("label.pattern", comment: ""),
                    systemImage: "text.line.last"
                )
                .font(.caption)
                .foregroundColor(.secondary)

                TextField(
                    NSLocalizedString("placeholder.pattern", comment: ""),
                    text: $viewModel.patternText
                )
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .pattern)
                .disabled(true) // Phase 1: Static mockup
            }

            // Comment input
            VStack(alignment: .leading, spacing: 6) {
                Label(
                    NSLocalizedString("label.comment", comment: ""),
                    systemImage: "bubble.left"
                )
                .font(.caption)
                .foregroundColor(.secondary)

                TextField(
                    NSLocalizedString("placeholder.comment", comment: ""),
                    text: $viewModel.commentText
                )
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .comment)
                .disabled(true) // Phase 1: Static mockup
            }

            // Validation error (if any)
            if let error = viewModel.validationError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }

            // Buttons
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text(NSLocalizedString("btn.cancel", comment: ""))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(true) // Phase 1: Static mockup

                Button(
                    action: {
                        if let pattern = viewModel.createPattern() {
                            onSave(pattern)
                        }
                    },
                    label: {
                        Text(NSLocalizedString("btn.save", comment: ""))
                            .frame(maxWidth: .infinity)
                    }
                )
                .buttonStyle(.borderedProminent)
                .disabled(true) // Phase 1: Static mockup
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: 400)
    }
}

#Preview {
    EditorView(viewModel: EditorViewModel())
}

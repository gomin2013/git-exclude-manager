import SwiftUI
import Shared

/// View for selecting/changing the active Git repository
struct RepositoryPickerView: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("label.repository", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let repo = viewModel.selectedRepository {
                    Text(repo.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(repo.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(NSLocalizedString("status.noRepository", comment: ""))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(
                action: { viewModel.browseRepository() },
                label: {
                    Text(NSLocalizedString("btn.browse", comment: ""))
                        .font(.caption)
                }
            )
            .disabled(true) // Phase 1: Static mockup
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(6)
    }
}

#Preview {
    RepositoryPickerView(viewModel: RepositoryViewModel())
        .padding()
        .frame(width: 320)
}

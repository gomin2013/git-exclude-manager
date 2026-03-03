import SwiftUI

/// Search/filter bar for patterns
struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField(
                NSLocalizedString("placeholder.search", comment: ""),
                text: $text
            )
            .textFieldStyle(.plain)

            if !text.isEmpty {
                Button(
                    action: { text = "" },
                    label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                )
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(6)
    }
}

#Preview {
    @Previewable @State var searchText = ""
    return SearchBar(text: $searchText)
        .padding()
}

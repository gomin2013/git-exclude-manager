import SwiftUI
import Shared

/// Main pattern list view
struct PatternsView: View {
    @ObservedObject var patternsVM: PatternsViewModel
    @ObservedObject var repositoryVM: RepositoryViewModel
    @State private var showingEditor = false

    var body: some View {
        VStack(spacing: 12) {
            RepositoryPickerView(viewModel: repositoryVM)
            Divider()
            SearchBar(text: $patternsVM.searchText)
                .padding(.horizontal, 12)

            if patternsVM.filteredPatterns.isEmpty {
                VStack {
                    Text(NSLocalizedString("message.noPatterns", comment: ""))
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(patternsVM.filteredPatterns) { pattern in
                        PatternRow(pattern: pattern)
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            HStack(spacing: 8) {
                Button(action: { showingEditor = true }, label: {
                    Image(systemName: "plus.circle")
                    Text(NSLocalizedString("btn.add", comment: ""))
                })
                .disabled(true)

                Spacer()

                Button(action: {}, label: {
                    Image(systemName: "arrow.down.doc")
                    Text(NSLocalizedString("btn.import", comment: ""))
                })
                .disabled(true)

                Button(action: {}, label: {
                    Image(systemName: "arrow.up.doc")
                    Text(NSLocalizedString("btn.export", comment: ""))
                })
                .disabled(true)
            }
            .padding(12)
            .font(.callout)

            Text(
                String(
                    format: NSLocalizedString("status.patternCount", comment: ""),
                    patternsVM.patterns.count,
                    patternsVM.patterns.filter { $0.isEnabled }.count
                )
            )
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingEditor) {
            EditorView(viewModel: EditorViewModel())
        }
    }
}

#Preview {
    PatternsView(
        patternsVM: PatternsViewModel(),
        repositoryVM: RepositoryViewModel()
    )
    .frame(width: 400, height: 600)
}

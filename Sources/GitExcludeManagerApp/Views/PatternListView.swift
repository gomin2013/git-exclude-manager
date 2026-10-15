import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Shared

/// The exclude-file items of the current repository.
/// ⌘-click / ⇧-click multi-select (native List selection), ⌘C copies to the Pattern Clipboard (and the system
/// pasteboard), ⌘V pastes pattern lines from the pasteboard, drag to reorder.
struct PatternListView: View {
    @ObservedObject var patternsVM: PatternsViewModel
    var onEdit: (GitExcludePattern) -> Void = { _ in }
    var onDelete: (UUID) -> Void = { _ in }

    @EnvironmentObject private var languageService: LanguageService
    @State private var selection = Set<UUID>()

    var body: some View {
        if patternsVM.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if patternsVM.filteredPatterns.isEmpty {
            Text(localized("message.noPatterns"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            list
        }
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(patternsVM.filteredPatterns) { pattern in
                PatternRow(
                    pattern: pattern,
                    onToggle: { patternsVM.togglePattern(pattern.id) },
                    onEdit: { onEdit(pattern) },
                    onDelete: { onDelete(pattern.id) },
                    onRename: { patternsVM.renameSection(pattern.id, to: $0) }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .listRowSeparator(.hidden)
                // Filtered indices don't map to file order, so reorder only when not searching.
                .moveDisabled(!patternsVM.searchText.isEmpty || pattern.isGitDefaultHeader)
            }
            .onMove(perform: move)
        }
        .listStyle(.plain)
        .contextMenu(forSelectionType: UUID.self) { ids in
            Button(localized("menu.copyToClipboard")) { copy(ids) }
                .disabled(!ids.contains { id in patternsVM.patterns.contains { $0.id == id && $0.kind == .pattern } })
        }
        .onCopyCommand {
            let text = patternsVM.copyToClipboard(selection, from: repositoryName)
            return text.isEmpty ? [] : [NSItemProvider(object: text as NSString)]
        }
        .onPasteCommand(of: [.plainText]) { providers in
            providers.first?.loadObject(ofClass: NSString.self) { object, _ in
                guard let text = object as? String else { return }
                Task { @MainActor in patternsVM.pasteText(text) }
            }
        }
        .onChange(of: patternsVM.selectedRepository) { selection = [] }  // ids belong to the previous repo
    }

    private var repositoryName: String {
        patternsVM.selectedRepository?.name ?? ""
    }

    /// Right-click → Copy: same as ⌘C, but the system pasteboard has to be written by hand.
    private func copy(_ ids: Set<UUID>) {
        let text = patternsVM.copyToClipboard(ids, from: repositoryName)
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func move(from source: IndexSet, to destination: Int) {
        patternsVM.movePatterns(from: source, to: destination)
    }
}

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Shared

/// The exclude-file items of the current repository.
/// ⌘-click / ⇧-click multi-select (native List selection), ⌘C copies to the Pattern Clipboard (and the system
/// pasteboard), ⌘V pastes pattern lines from the pasteboard, drag to reorder.
/// Keyboard: Space turns the selected patterns on/off, ⌫ deletes them (undo in History), Return / double-click edits.
struct PatternListView: View {
    @ObservedObject var patternsVM: PatternsViewModel
    var onEdit: (GitExcludePattern) -> Void = { _ in }
    var onAdd: () -> Void = {}

    @EnvironmentObject private var languageService: LanguageService
    @State private var selection = Set<UUID>()

    var body: some View {
        if patternsVM.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if patternsVM.filteredPatterns.isEmpty {
            if patternsVM.searchText.isEmpty {
                ContentUnavailableView {
                    Label(localized("message.noPatterns"), systemImage: "eye.slash")
                } description: {
                    Text(localized("empty.noPatterns.desc"))
                } actions: {
                    Button(localized("window.addTitle"), action: onAdd)
                }
            } else {
                ContentUnavailableView.search(text: patternsVM.searchText)
            }
        } else {
            list
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            rows
                // A new section lands at the bottom: bring it on screen so its heading field can take focus
                .onChange(of: patternsVM.editingSectionID) { _, id in
                    if let id { withAnimation { proxy.scrollTo(id) } }
                }
        }
    }

    private var rows: some View {
        List(selection: $selection) {
            ForEach(patternsVM.filteredPatterns) { pattern in
                PatternRow(
                    pattern: pattern,
                    onToggle: { patternsVM.togglePattern(pattern.id) },
                    onEdit: { onEdit(pattern) },
                    onDelete: { patternsVM.deletePattern(pattern.id) },
                    onRename: { patternsVM.renameSection(pattern.id, to: $0) },
                    isEditingSection: patternsVM.editingSectionID == pattern.id,
                    onEndEditing: { patternsVM.editingSectionID = nil }
                )
                .listRowSeparator(.hidden)
                // Filtered indices don't map to file order, so reorder only when not searching.
                .moveDisabled(!patternsVM.searchText.isEmpty || pattern.isGitDefaultHeader)
            }
            .onMove(perform: move)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .onDeleteCommand { delete(selection) }
        .onKeyPress(.space) {
            let ids = patternsVM.patterns.filter { selection.contains($0.id) && $0.kind == .pattern }.map(\.id)
            guard !ids.isEmpty else { return .ignored }
            ids.forEach(patternsVM.togglePattern)
            return .handled
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            Button(localized("menu.copyToClipboard")) { copy(ids) }
                .disabled(!ids.contains { id in patternsVM.patterns.contains { $0.id == id && $0.kind == .pattern } })
            Divider()
            Button(localized("menu.delete"), role: .destructive) { delete(ids) }
                .disabled(!patternsVM.patterns.contains { ids.contains($0.id) && !$0.isGitDefaultHeader })
        } primaryAction: { ids in
            // Double-click / Return: rename a section, edit a pattern
            guard ids.count == 1, let item = patternsVM.patterns.first(where: { ids.contains($0.id) }) else { return }
            switch item.kind {
            case .section: patternsVM.editingSectionID = item.id
            case .pattern: onEdit(item)
            case .comment: break
            }
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

    /// ⌫ / context menu: no confirmation — every delete is one step back in History. Git's header stays.
    private func delete(_ ids: Set<UUID>) {
        for item in patternsVM.patterns where ids.contains(item.id) && !item.isGitDefaultHeader {
            patternsVM.deletePattern(item.id)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        patternsVM.movePatterns(from: source, to: destination)
    }
}

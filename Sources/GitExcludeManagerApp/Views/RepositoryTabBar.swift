import SwiftUI
import Shared

/// Browser-style repository tabs: click to switch, drag to reorder, × to close, + to open another.
struct RepositoryTabBar: View {
    @ObservedObject var repositoryVM: RepositoryViewModel
    /// Called before switching tabs (PatternsView clears the search, like a browser).
    var onTabSwitch: () -> Void = {}
    var onOpenRepository: () -> Void = {}

    @EnvironmentObject private var languageService: LanguageService

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(repositoryVM.openRepositories, id: \.path) { repo in
                        tab(repo)
                            // Drag a tab onto another to reorder (payload = repo path)
                            .draggable(repo.path) { tab(repo).opacity(0.8) }
                            .dropDestination(for: String.self) { paths, _ in
                                guard let dropped = paths.first else { return false }
                                drop(dropped, onto: repo)
                                return true
                            }
                    }
                    // + sits right after the last tab, like a browser
                    Button(action: onOpenRepository, label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 28, height: 28)
                    })
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(localized("btn.openRepo"))
                    .accessibilityLabel(localized("btn.openRepo"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.windowBackgroundColor))
            Divider()
        }
    }

    /// Another tab → reorder; a Finder folder (arrives as a path string) → open it.
    private func drop(_ dropped: String, onto repo: GitRepository) {
        let path = URL(string: dropped).flatMap { $0.isFileURL ? $0.path : nil } ?? dropped
        if repositoryVM.openRepositories.contains(where: { $0.path == path }) {
            withAnimation(.easeInOut(duration: 0.15)) {
                repositoryVM.moveRepository(path: path, onto: repo.path)
            }
        } else {
            repositoryVM.openDropped([URL(fileURLWithPath: path)])
        }
    }

    private func tab(_ repo: GitRepository) -> some View {
        let isActive = repo.path == repositoryVM.selectedRepository?.path
        let activate = {
            guard !isActive else { return }
            onTabSwitch()
            repositoryVM.switchTo(repo)
        }
        return HStack(spacing: 6) {
            // Text + tap, not Button: an AppKit-backed Button swallows mouse-drag, so .draggable never fired
            Text(repo.name)
                .font(.callout)
                .fontWeight(isActive ? .semibold : .regular)
                .help(repo.displayPath)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(.default, activate)

            // × only when there is more than one tab (matches .prototype)
            if repositoryVM.openRepositories.count > 1 {
                Button(action: { repositoryVM.closeRepository(path: repo.path) }, label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                })
                .buttonStyle(.plain)
                .accessibilityLabel(localized("btn.close") + " " + repo.name)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(isActive ? Color.accentColor : Color.secondary.opacity(0.12))
        .foregroundStyle(isActive ? Color.white : Color.primary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())  // whole tab (incl. padding) is clickable + draggable
        .onTapGesture(perform: activate)
    }
}

/// Dashed frame + hint while a Finder folder hovers over the window.
struct DropTargetOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
            .background(Color.accentColor.opacity(0.08))
            .overlay {
                Label(localized("hint.dropRepository"), systemImage: "folder.badge.plus")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
            }
            .padding(6)
            .allowsHitTesting(false)
    }
}

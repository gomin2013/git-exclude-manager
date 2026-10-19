import SwiftUI
import Shared

/// Browser-style repository tabs: click to switch, drag to reorder, × to close, + to open another.
/// The selected tab is filled with the chosen accent (every palette colour keeps white text at 5.0:1); with the
/// System accent — whose contrast we can't know — it's a neutral fill with primary text.
struct RepositoryTabBar: View {
    @ObservedObject var repositoryVM: RepositoryViewModel
    var accent = AccentChoice.system
    /// Called before switching tabs (PatternsView clears the search, like a browser).
    var onTabSwitch: () -> Void = {}
    var onOpenRepository: () -> Void = {}

    @EnvironmentObject private var languageService: LanguageService
    @State private var hovered: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
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
                        Image(systemName: "plus").frame(width: 26, height: 26)
                    })
                    .buttonStyle(.borderless)
                    .help(localized("btn.openRepo") + " (⌘O)")
                    .accessibilityLabel(localized("btn.openRepo"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        let filled = isActive && accent.color != nil
        let activate = {
            guard !isActive else { return }
            onTabSwitch()
            repositoryVM.switchTo(repo)
        }
        return HStack(spacing: 6) {
            // Text + tap, not Button: an AppKit-backed Button swallows mouse-drag, so .draggable never fired
            Text(repo.name)
                .font(.app(13, isActive ? .semibold : .regular))
                .lineLimit(1)
                .help(repo.displayPath)
                .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
                .accessibilityAction(.default, activate)

            // × on the selected or hovered tab — closing the last one shows the Welcome screen
            if isActive || hovered == repo.path {
                Button(action: { repositoryVM.closeRepository(path: repo.path) }, label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                })
                .buttonStyle(.plain)
                .accessibilityLabel(localized("btn.close") + " " + repo.name)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .foregroundStyle(filled ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .background {
            if filled {
                Capsule().fill(.tint)
            } else if isActive || hovered == repo.path {
                Capsule().fill(.quaternary)
            }
        }
        .contentShape(Capsule())  // whole tab is clickable + draggable
        .onTapGesture(perform: activate)
        .onHover { hovered = $0 ? repo.path : (hovered == repo.path ? nil : hovered) }
    }
}

/// Dashed frame + hint while a Finder folder hovers over the window.
struct DropTargetOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(.tint, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
            .background(.tint.opacity(0.08))
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

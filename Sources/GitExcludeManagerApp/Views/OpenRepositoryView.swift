import SwiftUI
import Shared

/// Modal for opening a repository — recent list + Browse button
/// Matches .prototype openRepoDialog
struct OpenRepositoryView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    var onDismiss: () -> Void = {}

    @EnvironmentObject private var languageService: LanguageService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header
            HStack {
                Text(localized("openRepo.title"))
                    .font(.headline)
                Spacer()
                CloseButton(action: onDismiss)
            }
            .padding(14)

            Divider()

            // MARK: - Body
            VStack(alignment: .leading, spacing: 10) {
                Text(localized("label.recentRepos"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                if viewModel.recentRepositories.isEmpty {
                    Text(localized("openRepo.noRecent"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 2) {
                        ForEach(viewModel.recentRepositories) { repo in
                            recentItem(repo)
                        }
                    }
                }

                Divider()

                Button(action: {
                    onDismiss()
                    viewModel.browseRepository()
                }, label: {
                    Text(localized("btn.browse"))
                        .frame(maxWidth: .infinity)
                })
                .controlSize(.large)
            }
            .padding(14)
        }
        .frame(width: 440)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Private

    @ViewBuilder
    private func recentItem(_ repo: GitRepository) -> some View {
        let isActive = viewModel.selectedRepository?.path == repo.path

        HStack(spacing: 6) {
            Button(action: {
                viewModel.selectRepository(url: URL(fileURLWithPath: repo.path))
                onDismiss()
            }, label: {
                recentItemLabel(repo)
            })
            .buttonStyle(.plain)
            .accessibilityLabel(repo.name)

            Button(action: { viewModel.removeRecent(path: repo.path) }, label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            })
            .buttonStyle(.plain)
            .help(localized("menu.removeRecent"))
            .accessibilityLabel(localized("menu.removeRecent") + " " + repo.name)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive
                    ? Color.accentColor.opacity(0.12)
                    : Color(.controlBackgroundColor).opacity(0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .contextMenu {
            Button(localized("menu.removeRecent"), role: .destructive) { viewModel.removeRecent(path: repo.path) }
        }
    }

    private func recentItemLabel(_ repo: GitRepository) -> some View {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(repo.displayPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(relativeTimeString(from: repo.lastAccessedAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
    }

    /// Localized by the system ("5 min ago" / "5 นาทีที่แล้ว") — was hard-coded English.
    private func relativeTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: languageService.currentLanguage.rawValue)
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct OpenRepositoryView_Previews: PreviewProvider {
    static var previews: some View {
        OpenRepositoryView(viewModel: RepositoryViewModel())
            .environmentObject(LanguageService.shared)
    }
}

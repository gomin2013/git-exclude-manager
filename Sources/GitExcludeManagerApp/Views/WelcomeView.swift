import SwiftUI
import Shared

/// Shown while no repository is open — what a new user sees first (they have no open tabs and no recents).
/// Open goes straight to the folder picker; the sheet with its empty recent list is only for the + tab.
struct WelcomeView: View {
    @ObservedObject var repositoryVM: RepositoryViewModel
    var onShowHelp: () -> Void = {}

    @EnvironmentObject private var languageService: LanguageService

    private static let website = URL(string: "https://gomin2013.github.io/git-exclude-manager/")!
    private static let github = URL(string: "https://github.com/gomin2013/git-exclude-manager")!

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)
                VStack(spacing: 6) {
                    Text("Git Exclude Manager").font(.app(26, .semibold))
                    Text(localized("about.desc"))
                        .font(.app(14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
                Button(action: repositoryVM.browseRepository) {
                    HStack(spacing: 10) {
                        Text(localized("btn.openRepo") + "…")
                        Text("⌘O").opacity(0.7)
                    }
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Label(localized("empty.noRepo.desc"), systemImage: "arrow.down.doc")
                    .font(.app(12))
                    .foregroundStyle(.secondary)
                if !repositoryVM.recentRepositories.isEmpty { recent }
                HStack(spacing: 14) {
                    Button(localized("menu.help"), action: onShowHelp).buttonStyle(.link)
                    Link(localized("link.website"), destination: Self.website)
                    Link("GitHub", destination: Self.github)
                }
                .font(.app(12))
                .padding(.top, 4)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center)
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(localized("label.recentRepos"))
                .font(.app(12, .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
            ForEach(repositoryVM.recentRepositories.prefix(5)) { repo in
                Button {
                    repositoryVM.selectRepository(url: URL(fileURLWithPath: repo.path))
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "folder").foregroundStyle(.tint)
                        Text(repo.name).font(.app(13, .medium)).lineLimit(1)
                        Text(repo.displayPath)
                            .font(.app(12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(repo.path)
            }
        }
        .frame(maxWidth: 420)
        .padding(.top, 6)
    }
}

import Foundation
import Shared

/// ViewModel for repository selection and management
@MainActor
public class RepositoryViewModel: ObservableObject {
    @Published var selectedRepository: GitRepository?
    @Published var recentRepositories: [GitRepository] = []
    @Published var errorMessage: String?

    public init() {
        // Phase 1: Initialize with mock data
        self.selectedRepository = MockData.sampleRepository
        self.recentRepositories = [MockData.sampleRepository]
    }

    /// Stub: Select a repository by path
    func selectRepository(url: URL) {
        let path = url.path
        guard GitRepository.isValidRepository(at: path) else {
            self.errorMessage = NSLocalizedString("error.invalidRepository", comment: "")
            return
        }

        let repo = GitRepository(
            path: path,
            lastAccessedAt: Date()
        )
        self.selectedRepository = repo
        self.errorMessage = nil

        // Phase 2: Save to UserDefaults
    }

    /// Browse for a Git repository
    func browseRepository() {
        // Phase 2: Present NSOpenPanel for folder selection
    }

    /// Stub: Load recent repositories
    func loadRecentRepositories() {
        // Phase 2: Load from UserDefaults
        self.recentRepositories = [MockData.sampleRepository]
    }
}

import Foundation
import Shared

/// ViewModel for managing Git exclude patterns
@MainActor
public class PatternsViewModel: ObservableObject {
    @Published var patterns: [GitExcludePattern] = []
    @Published var selectedRepository: GitRepository?
    @Published var searchText: String = ""
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    public init() {
        // Phase 1: Initialize with mock data
        self.patterns = MockData.samplePatterns
        self.selectedRepository = MockData.sampleRepository
    }

    /// Filtered patterns based on search text
    var filteredPatterns: [GitExcludePattern] {
        if searchText.isEmpty {
            return patterns
        }
        return patterns.filter { pattern in
            pattern.pattern.localizedCaseInsensitiveContains(searchText) ||
            (pattern.comment?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    /// Stub: Add a new pattern
    func addPattern(_ pattern: GitExcludePattern) {
        // Phase 2: Implement XPC call to helper
        self.patterns.append(pattern)
    }

    /// Stub: Edit an existing pattern
    func editPattern(_ pattern: GitExcludePattern) {
        // Phase 2: Implement XPC call to helper
        if let index = self.patterns.firstIndex(where: { $0.id == pattern.id }) {
            self.patterns[index] = pattern
        }
    }

    /// Stub: Delete a pattern
    func deletePattern(_ patternID: UUID) {
        // Phase 2: Implement XPC call to helper
        self.patterns.removeAll { $0.id == patternID }
    }

    /// Stub: Toggle pattern enabled/disabled state
    func togglePattern(_ patternID: UUID) {
        // Phase 2: Implement XPC call to helper
        if let index = self.patterns.firstIndex(where: { $0.id == patternID }) {
            self.patterns[index].isEnabled.toggle()
        }
    }

    /// Stub: Load patterns from repository
    func loadPatterns(from repository: GitRepository) {
        // Phase 2: Implement XPC call to helper
        self.selectedRepository = repository
        self.patterns = MockData.samplePatterns
    }

    /// Stub: Export patterns to file
    func exportPatterns(to url: URL) {
        // Phase 2: Implement file export
    }

    /// Stub: Import patterns from file
    func importPatterns(from url: URL) {
        // Phase 2: Implement file import
    }
}

// MARK: - Mock Data (Phase 1)

struct MockData {
    static let sampleRepository = GitRepository(
        id: UUID(),
        path: "/Users/username/Projects/MyApp",
        name: "MyApp",
        lastAccessedAt: Date()
    )

    static let samplePatterns: [GitExcludePattern] = [
        GitExcludePattern(
            id: UUID(),
            pattern: "*.log",
            isEnabled: true,
            comment: "Log files",
            createdAt: Date().addingTimeInterval(-86400),
            modifiedAt: Date().addingTimeInterval(-86400)
        ),
        GitExcludePattern(
            id: UUID(),
            pattern: "node_modules/",
            isEnabled: true,
            comment: "NPM dependencies",
            createdAt: Date().addingTimeInterval(-172800),
            modifiedAt: Date().addingTimeInterval(-172800)
        ),
        GitExcludePattern(
            id: UUID(),
            pattern: ".env",
            isEnabled: true,
            comment: "Environment variables",
            createdAt: Date().addingTimeInterval(-259200),
            modifiedAt: Date().addingTimeInterval(-259200)
        ),
        GitExcludePattern(
            id: UUID(),
            pattern: "build/",
            isEnabled: false,
            comment: "Build output (disabled)",
            createdAt: Date().addingTimeInterval(-345600),
            modifiedAt: Date().addingTimeInterval(-345600)
        ),
        GitExcludePattern(
            id: UUID(),
            pattern: ".DS_Store",
            isEnabled: true,
            comment: nil,
            createdAt: Date().addingTimeInterval(-432000),
            modifiedAt: Date().addingTimeInterval(-432000)
        )
    ]
}

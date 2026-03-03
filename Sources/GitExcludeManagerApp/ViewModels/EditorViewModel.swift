import Foundation
import Shared

/// ViewModel for editing/adding a Git exclude pattern
@MainActor
public class EditorViewModel: ObservableObject {
    @Published var patternText: String = ""
    @Published var commentText: String = ""
    @Published var validationError: String?

    private var editingPatternID: UUID?

    /// True when editing an existing pattern (vs adding new)
    var isEditing: Bool { editingPatternID != nil }

    public init(pattern: GitExcludePattern? = nil) {
        if let pattern = pattern {
            self.patternText = pattern.pattern
            self.commentText = pattern.comment ?? ""
            self.editingPatternID = pattern.id
        }
    }

    /// Validates the current input
    var isValid: Bool {
        !patternText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Returns error message if validation fails
    var errorMessage: String? {
        let candidate = GitExcludePattern(
            id: editingPatternID ?? UUID(),
            pattern: patternText,
            isEnabled: true,
            comment: commentText.isEmpty ? nil : commentText
        )
        return candidate.validationError
    }

    /// Creates a pattern from current input
    func createPattern() -> GitExcludePattern? {
        let trimmed = patternText.trimmingCharacters(in: .whitespaces)
        let candidate = GitExcludePattern(
            id: editingPatternID ?? UUID(),
            pattern: trimmed,
            isEnabled: true,
            comment: commentText.isEmpty ? nil : commentText,
            createdAt: Date(),
            modifiedAt: Date()
        )

        if let error = candidate.validationError {
            self.validationError = error
            return nil
        }

        self.validationError = nil
        return candidate
    }

    /// Resets form state
    func reset() {
        patternText = ""
        commentText = ""
        validationError = nil
        editingPatternID = nil
    }
}

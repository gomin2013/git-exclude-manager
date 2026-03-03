import Foundation
import Shared

/// ViewModel for editing/adding a Git exclude pattern
@MainActor
public class EditorViewModel: ObservableObject {
    @Published var patternText: String = ""
    @Published var commentText: String = ""
    @Published var validationError: String?

    private var editingPatternID: UUID?

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
        guard !patternText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return NSLocalizedString("error.invalidPattern", comment: "")
        }
        return nil
    }

    /// Creates a pattern from current input
    func createPattern() -> GitExcludePattern? {
        guard !patternText.trimmingCharacters(in: .whitespaces).isEmpty else {
            self.validationError = NSLocalizedString("error.invalidPattern", comment: "")
            return nil
        }

        self.validationError = nil
        let pattern = GitExcludePattern(
            id: editingPatternID ?? UUID(),
            pattern: patternText,
            isEnabled: true,
            comment: commentText.isEmpty ? nil : commentText,
            createdAt: Date(),
            modifiedAt: Date()
        )
        return pattern
    }

    /// Resets form state
    func reset() {
        patternText = ""
        commentText = ""
        validationError = nil
        editingPatternID = nil
    }
}

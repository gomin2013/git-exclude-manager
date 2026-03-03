import Foundation

/// XPC protocol for communication between main app and helper daemon
@objc public protocol HelperProtocol: NSObjectProtocol {
    /// Reads the `.git/info/exclude` file from the given repository
    /// - Parameters:
    ///   - repoPath: Absolute path to the Git repository
    ///   - completion: Callback with file content data or error
    func readExcludeFile(
        repoPath: String,
        completion: @escaping (Data?, NSError?) -> Void
    )

    /// Writes content to `.git/info/exclude` in the given repository
    /// - Parameters:
    ///   - repoPath: Absolute path to the Git repository
    ///   - content: Plain text content to write
    ///   - completion: Callback with success bool and optional error
    func writeExcludeFile(
        repoPath: String,
        content: String,
        completion: @escaping (Bool, NSError?) -> Void
    )

    /// Lists available Git repositories (Phase 2+)
    /// - Parameter completion: Callback with repository paths or error
    func listRepositories(completion: @escaping ([String]?, NSError?) -> Void)

    /// Validates a pattern against gitignore syntax (Phase 2+)
    /// - Parameters:
    ///   - pattern: Pattern string to validate
    ///   - completion: Callback with validation result
    func validatePattern(pattern: String, completion: @escaping (Bool) -> Void)

    /// Gets the helper daemon version
    func getVersion(completion: @escaping (String?) -> Void)

    /// Simple health check
    func ping(completion: @escaping (Bool) -> Void)
}

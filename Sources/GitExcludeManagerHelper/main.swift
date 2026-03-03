import Foundation
import Shared

/// Git Exclude Manager Helper Daemon
/// Handles privileged file operations for the main app via XPC

class HelperService: NSObject, HelperProtocol {
    static let helperIdentifier = "com.gitexcludemanager.helper"

    // MARK: - HelperProtocol Implementation

    func readExcludeFile(repoPath: String, completion: @escaping (Data?, NSError?) -> Void) {
        do {
            let service = ExcludeFileService()
            let data = try service.readExcludeFile(repoPath: repoPath)
            completion(data, nil)
        } catch let helperError as HelperError {
            completion(nil, Self.makeNSError(from: helperError))
        } catch {
            completion(nil, Self.makeNSError(from: .unknown(error.localizedDescription)))
        }
    }

    func writeExcludeFile(repoPath: String, content: String, completion: @escaping (Bool, NSError?) -> Void) {
        do {
            let service = ExcludeFileService()
            try service.writeExcludeFile(repoPath: repoPath, content: content)
            completion(true, nil)
        } catch let helperError as HelperError {
            completion(false, Self.makeNSError(from: helperError))
        } catch {
            completion(false, Self.makeNSError(from: .unknown(error.localizedDescription)))
        }
    }

    func restoreBackup(repoPath: String, completion: @escaping (Bool, NSError?) -> Void) {
        do {
            try ExcludeFileService().restoreBackup(repoPath: repoPath)
            completion(true, nil)
        } catch let helperError as HelperError {
            completion(false, Self.makeNSError(from: helperError))
        } catch {
            completion(false, Self.makeNSError(from: .unknown(error.localizedDescription)))
        }
    }

    func listRepositories(completion: @escaping ([String]?, NSError?) -> Void) {
        // Phase 3: Implement repository discovery via UserDefaults + security-scoped bookmarks
        completion(nil, NSError(domain: "NotImplemented", code: 1))
    }

    func validatePattern(pattern: String, completion: @escaping (Bool) -> Void) {
        // Phase 3: Implement gitignore syntax validation (currently basic check)
        completion(!pattern.isEmpty)
    }

    func getVersion(completion: @escaping (String?) -> Void) {
        completion("1.0.0-alpha")
    }

    func ping(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    // MARK: - Private Methods

    private static func makeNSError(from error: HelperError) -> NSError {
        let code: Int
        let description: String

        switch error {
        case .fileReadError(let message):
            code = 1
            description = message
        case .fileWriteError(let message):
            code = 2
            description = message
        case .invalidRepository(let message):
            code = 3
            description = message
        case .permissionDenied:
            code = 4
            description = "Permission denied"
        case .connectionFailed:
            code = 5
            description = "Connection failed"
        case .invalidData(let message):
            code = 6
            description = message
        case .unknown(let message):
            code = 999
            description = message
        }

        return NSError(
            domain: "HelperError",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }
}

// MARK: - Main Entry Point

let listener = NSXPCListener(machServiceName: HelperService.helperIdentifier)
let delegate = HelperServiceDelegate()
listener.delegate = delegate
listener.resume()

// Keep the helper running
RunLoop.main.run()

// MARK: - XPC Listener Delegate

class HelperServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // ponytail: identifier-only check; ad-hoc signatures can spoof it.
        // Add `and anchor apple generic and certificate leaf[subject.OU] = "<TEAMID>"` once Developer ID signed (Phase 4).
        newConnection.setCodeSigningRequirement("identifier \"com.gitexcludemanager.app\"")
        let exportedObject = HelperService()
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedObject = exportedObject
        newConnection.resume()
        return true
    }
}

import Foundation
import Shared

/// Git Exclude Manager Helper Daemon
/// Handles privileged file operations for the main app via XPC

class HelperService: NSObject, HelperProtocol {
    static let helperIdentifier = "com.gitexcludemanager.helper"

    // MARK: - HelperProtocol Implementation (Stubs for Phase 1)

    func readExcludeFile(repoPath: String, completion: @escaping (Data?, NSError?) -> Void) {
        // Phase 2: Implement actual file reading
        completion(nil, NSError(domain: "NotImplemented", code: 1))
    }

    func writeExcludeFile(repoPath: String, content: String, completion: @escaping (Bool, NSError?) -> Void) {
        // Phase 2: Implement actual file writing
        completion(false, NSError(domain: "NotImplemented", code: 1))
    }

    func listRepositories(completion: @escaping ([String]?, NSError?) -> Void) {
        // Phase 2: Implement repository discovery
        completion(nil, NSError(domain: "NotImplemented", code: 1))
    }

    func validatePattern(pattern: String, completion: @escaping (Bool) -> Void) {
        // Phase 2: Implement pattern validation
        completion(!pattern.isEmpty)
    }

    func getVersion(completion: @escaping (String?) -> Void) {
        completion("1.0.0-alpha")
    }

    func ping(completion: @escaping (Bool) -> Void) {
        completion(true)
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
        let exportedObject = HelperService()
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedObject = exportedObject
        newConnection.resume()
        return true
    }
}

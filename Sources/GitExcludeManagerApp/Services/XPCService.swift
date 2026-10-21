import Foundation
import Shared

/// Bridge service between the app and helper daemon.
///
/// Implemented as an `actor` to protect internal state (`connection`) without
/// requiring `@MainActor`.  XPC Obj-C completion handlers are delivered on XPC
/// internal queues; we hop results back to `DispatchQueue.main` via GCD (NOT
/// `Task { @MainActor in }`, which triggers `dispatch_assert_queue_fail` because
/// Swift checks the executor *before* entering the Task body).
public actor XPCService {
    // MARK: - Public Interface

    /// `endpoint` connects to an in-process anonymous listener instead of the launchd Mach service
    /// (integration tests run the real `HelperService` over real XPC that way).
    public init(endpoint: NSXPCListenerEndpoint? = nil, timeout: TimeInterval = 10) {
        self.endpoint = endpoint
        self.timeout = timeout
    }

    private let endpoint: NSXPCListenerEndpoint?
    /// launchd can keep an updated helper registered but never start it — this app is ad-hoc signed, so until the
    /// user turns it off and on in Login Items (seen with Hosts Manager 2026-10-21). Then nothing replies and nothing
    /// fails: every request gives up after this many seconds instead of loading forever.
    private let timeout: TimeInterval

    /// `completion`, called once: with the reply, an error, or `timedOut` — whichever comes first.
    private func once<T: Sendable>(
        _ completion: @escaping @Sendable (T) -> Void, timedOut: T
    ) -> @Sendable (T) -> Void {
        let gate = Once(completion)
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { gate(timedOut) }
        return { gate($0) }
    }

    public func readExcludeFile(
        repoPath: String,
        completion: @escaping @Sendable (Result<Data, HelperError>) -> Void
    ) {
        let completion = once(completion, timedOut: .failure(.connectionFailed))
        guard let helper = remoteHelper(onError: { completion(.failure($0)) }) else { return }

        helper.readExcludeFile(repoPath: repoPath) { data, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(Self.mapNSError(error)))
                    return
                }
                guard let data else {
                    completion(.failure(.invalidData("Missing file payload")))
                    return
                }
                completion(.success(data))
            }
        }
    }

    public func writeExcludeFile(
        repoPath: String,
        content: String,
        completion: @escaping @Sendable (Result<Void, HelperError>) -> Void
    ) {
        let completion = once(completion, timedOut: .failure(.connectionFailed))
        guard let helper = remoteHelper(onError: { completion(.failure($0)) }) else { return }

        helper.writeExcludeFile(repoPath: repoPath, content: content) { success, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(Self.mapNSError(error)))
                } else if success {
                    completion(.success(()))
                } else {
                    completion(.failure(.fileWriteError(repoPath)))
                }
            }
        }
    }

    public func restoreBackup(
        repoPath: String,
        completion: @escaping @Sendable (Result<Void, HelperError>) -> Void
    ) {
        let completion = once(completion, timedOut: .failure(.connectionFailed))
        guard let helper = remoteHelper(onError: { completion(.failure($0)) }) else { return }

        helper.restoreBackup(repoPath: repoPath) { success, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(Self.mapNSError(error)))
                } else if success {
                    completion(.success(()))
                } else {
                    completion(.failure(.fileWriteError(repoPath)))
                }
            }
        }
    }

    public func validatePattern(
        _ pattern: String,
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        let completion = once(completion, timedOut: false)
        guard let helper = remoteHelper(onError: { _ in completion(false) }) else { return }

        helper.validatePattern(pattern: pattern) { isValid in
            DispatchQueue.main.async { completion(isValid) }
        }
    }

    public func ping(completion: @escaping @Sendable (Bool) -> Void) {
        let completion = once(completion, timedOut: false)
        guard let helper = remoteHelper(onError: { _ in completion(false) }) else { return }

        helper.ping { isAlive in
            DispatchQueue.main.async { completion(isAlive) }
        }
    }

    /// Invalidates the XPC connection. Call when the app goes to background.
    public func invalidate() {
        connection?.invalidate()
        connection = nil
    }

    // MARK: - Private

    private var connection: NSXPCConnection?

    private func connectIfNeeded() -> NSXPCConnection? {
        if let connection { return connection }

        let conn = endpoint.map(NSXPCConnection.init(listenerEndpoint:))
            ?? NSXPCConnection(machServiceName: "com.gitexcludemanager.helper")
        conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        // Use an isolated Task to clear connection on the actor
        conn.invalidationHandler = { [weak self] in
            guard let self else { return }
            Task { await self.clearConnection() }
        }
        conn.interruptionHandler = { [weak self] in
            guard let self else { return }
            Task { await self.clearConnection() }
        }
        conn.resume()
        self.connection = conn
        return conn
    }

    private func clearConnection() {
        connection = nil
    }

    private func remoteHelper(
        onError: @escaping @Sendable (HelperError) -> Void
    ) -> (any HelperProtocol)? {
        guard let conn = connectIfNeeded() else {
            DispatchQueue.main.async { onError(.connectionFailed) }
            return nil
        }
        guard let helper = conn.remoteObjectProxyWithErrorHandler({ _ in
            DispatchQueue.main.async { onError(.connectionFailed) }
        }) as? any HelperProtocol else {
            DispatchQueue.main.async { onError(.connectionFailed) }
            return nil
        }
        return helper
    }

    private static func mapNSError(_ error: NSError) -> HelperError {
        guard error.domain == "HelperError" else {
            return .unknown(error.localizedDescription)
        }
        switch error.code {
        case 1: return .fileReadError(error.localizedDescription)
        case 2: return .fileWriteError(error.localizedDescription)
        case 3: return .invalidRepository(error.localizedDescription)
        case 4: return .permissionDenied
        case 5: return .connectionFailed
        case 6: return .invalidData(error.localizedDescription)
        default: return .unknown(error.localizedDescription)
        }
    }
}

/// Calls the wrapped closure the first time only.
private final class Once<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var body: (@Sendable (T) -> Void)?

    init(_ body: @escaping @Sendable (T) -> Void) { self.body = body }

    func callAsFunction(_ value: T) {
        lock.lock()
        let pending = body
        body = nil
        lock.unlock()
        pending?(value)
    }
}

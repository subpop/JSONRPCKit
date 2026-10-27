import Foundation
import Synchronization

@testable import JSONRPCKit

/// In-memory transport that captures outbound payloads and lets tests
/// inject inbound ones. Used for handler-dispatch tests.
final class CapturingTransport: Transport, @unchecked Sendable {
    let messages: AsyncStream<Data>
    private let incoming: AsyncStream<Data>.Continuation
    let state: AsyncStream<TransportState>
    private let stateContinuation: AsyncStream<TransportState>.Continuation

    private let sentMutex = Mutex<[Data]>([])
    var sent: [Data] { sentMutex.withLock { $0 } }

    init() {
        var incoming: AsyncStream<Data>.Continuation!
        self.messages = AsyncStream { incoming = $0 }
        self.incoming = incoming
        var stateContinuation: AsyncStream<TransportState>.Continuation!
        self.state = AsyncStream { stateContinuation = $0 }
        self.stateContinuation = stateContinuation
    }

    func start() async throws {
        stateContinuation.yield(.started)
    }

    func send(_ data: Data) async throws {
        sentMutex.withLock { $0.append(data) }
    }

    func inject(_ data: Data) {
        incoming.yield(data)
    }

    func close() async {
        incoming.finish()
    }

    func awaitSent(
        matching predicate: @escaping @Sendable (Data) -> Bool,
        timeoutNanoseconds: UInt64 = 2_000_000_000
    ) async throws -> Data {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            for data in sent where predicate(data) {
                return data
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw TableTestError.timedOut
    }
}

enum TableTestError: Error {
    case timedOut
}

/// Encodes a JSON-RPC request for injection.
func rpcRequestData(id: RequestID, method: String, params: JSONValue? = nil) throws -> Data {
    try JSONRPCMessage.request(JSONRPCRequest(id: id, method: method, params: params)).encoded()
}

/// Encodes a JSON-RPC notification for injection.
func rpcNotificationData(method: String, params: JSONValue? = nil) throws -> Data {
    try JSONRPCMessage.notification(JSONRPCNotification(method: method, params: params)).encoded()
}

/// Predicate matching a response/error for `id`.
func isResponseData(for id: RequestID) -> @Sendable (Data) -> Bool {
    { data in
        (try? JSONRPCMessage(data: data)).map {
            switch $0 {
            case .response(let response): return response.id == id
            case .error(let errorResponse): return errorResponse.id == id
            default: return false
            }
        } ?? false
    }
}

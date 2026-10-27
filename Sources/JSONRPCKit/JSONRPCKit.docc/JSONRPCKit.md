# ``JSONRPCKit``

Transport-agnostic JSON-RPC 2.0 for Swift, with newline-delimited JSON (ND-JSON)
transports over stdio and child processes.

## Overview

JSONRPCKit implements the JSON-RPC 2.0 message model on top of a single
transport-agnostic peer:

- Speak the protocol with ``JSONRPCPeer`` over any ``Transport``: register
  request and notification handlers per method, and send typed requests with
  optional timeouts.
- Be the subprocess with ``StdioTransport``, which frames messages as ND-JSON
  over this process's own stdin/stdout; or launch a counterpart with
  ``ProcessTransport``, which speaks ND-JSON over the child's pipes.
- Model parameters, results, and `_meta`-style payloads either as concrete
  `Codable` types or as arbitrary JSON with ``JSONValue``.
- Control the error codes sent back to callers by conforming to
  ``JSONRPCErrorConvertible``.

```swift
struct AddArgs: Codable, Sendable { var a: Int, b: Int }
struct Sum: Codable, Sendable { var value: Int }

let transport = ProcessTransport(command: "some-server", args: ["--stdio"])
let peer = JSONRPCPeer(transport: transport)

// Serve incoming requests.
await peer.onRequest(method: "add") { params in
    guard let params else {
        throw JSONRPCErrorObject(code: -32602, message: "params required")
    }
    let args = try params.decode(as: AddArgs.self)
    return try JSONValue(encoding: Sum(value: args.a + args.b))
}

try await peer.start()

// Send one.
let sum: Sum = try await peer.sendRequest(
    method: "add", params: AddArgs(a: 1, b: 2), timeout: 5)
await peer.close()
```

## Topics

### Peer

- ``JSONRPCPeer``
- ``JSONRPCPeerError``

### Messages

- ``JSONRPCMessage``
- ``JSONRPCRequest``
- ``JSONRPCNotification``
- ``JSONRPCResponse``
- ``JSONRPCErrorResponse``
- ``JSONRPCErrorObject``
- ``JSONRPCErrorConvertible``
- ``JSONRPCDecodingError``
- ``RequestID``

### Transports

- ``Transport``
- ``TransportState``
- ``StdioTransport``
- ``ProcessTransport``
- ``ProcessTransportError``

### JSON Values

- ``JSONValue``

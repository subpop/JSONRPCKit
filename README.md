# JSONRPCKit

A transport-agnostic [JSON-RPC 2.0](https://www.jsonrpc.org/specification) implementation
in Swift, plus newline-delimited JSON (ND-JSON) transports over stdio and child
processes.

## Requirements

- Swift 6.3 or later
- macOS 15 or later (Linux should work, but is untested)

## Overview

| Symbol | Purpose |
| --- | --- |
| `JSONRPCPeer` | An actor that speaks JSON-RPC 2.0 over any `Transport`: register request/notification handlers and send typed requests with optional timeouts. |
| `Transport` | A bidirectional, message-oriented channel abstraction (`messages`, `state`, `start`, `send`, `close`). Implement your own for WebSocket, in-memory pipes, etc. |
| `StdioTransport` | ND-JSON over the current process's stdin/stdout — use when *you* are the subprocess. |
| `ProcessTransport` | Spawns a child process and speaks ND-JSON over its pipes — use when *you* launch the counterpart. |
| `JSONValue` | A `Sendable`, `Codable` representation of arbitrary JSON for `_meta`-style fields, opaque payloads, and parameter passthrough. |
| `RequestID` | The string-or-number request identifier from the spec. |

## Usage

```swift
import JSONRPCKit

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

Request handlers may throw `JSONRPCErrorConvertible` to control the JSON-RPC error
code and payload returned to the caller; any other error becomes `-32603` (internal
error). Unknown methods are answered with `-32601` (method not found). Outgoing
`sendRequest` calls support a `timeout` and honor task cancellation.

Diagnostic logging goes through [swift-log](https://github.com/apple/swift-log); pass
your own `Logger` or accept the defaults. Never log to a transport's stdout — it
carries JSON-RPC framing.

## Testing

```sh
swift test
```

The suite includes integration tests that spawn real child processes (`/bin/cat`,
`/bin/sh`).

## Documentation

API reference is generated with Swift DocC and published to GitHub Pages by
`.github/workflows/docs.yml` on every push to `main`.

Preview locally:

```sh
swift package --allow-writing-to-directory ./docs \
  generate-documentation --target JSONRPCKit \
  --output-path ./docs \
  --transform-for-static-hosting \
  --hosting-base-path JSONRPCKit
```

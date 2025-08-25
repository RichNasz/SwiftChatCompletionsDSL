# Architecture

Understanding the technical design and patterns used in SwiftChatCompletionsDSL.

## Overview

SwiftChatCompletionsDSL is built using modern Swift patterns that prioritize type safety, performance, and maintainability. The architecture leverages result builders, actor-based concurrency, and protocol-oriented design to create a robust, extensible DSL.

## Core Design Patterns

### Result Builder Pattern

The DSL uses Swift's result builder feature to create declarative syntax for building chat requests and configurations.

```swift
@resultBuilder
public struct ChatBuilder {
    public static func buildBlock(_ components: any ChatMessage...) -> [any ChatMessage] {
        Array(components)
    }
    
    public static func buildEither(first: [any ChatMessage]) -> [any ChatMessage] {
        first
    }
    
    public static func buildOptional(_ component: [any ChatMessage]?) -> [any ChatMessage] {
        component ?? []
    }
}
```

This pattern enables natural Swift syntax for building message sequences:

```swift
ChatRequest(model: "gpt-4") {
    // Configuration parameters
    try Temperature(0.7)
    try MaxTokens(150)
} messages: {
    // Message sequence
    TextMessage(role: .system, content: "You are helpful")
    TextMessage(role: .user, content: "Hello")
    if includeContext {
        TextMessage(role: .assistant, content: "Previous context...")
    }
}
```

**Benefits:**
- **Compile-time validation**: Invalid structures are caught at build time
- **Control flow support**: Use `if`, `for`, and other Swift constructs naturally
- **Type safety**: Strong typing prevents configuration errors
- **Readability**: Code reads like natural language

### Actor-Based Concurrency

The `LLMClient` is implemented as an actor to ensure thread safety in concurrent environments:

```swift
@available(macOS 12.0, iOS 15.0, *)
public actor LLMClient {
    private let baseURL: String
    private let apiKey: String
    private let session: URLSession
    
    public func complete(_ request: ChatRequest) async throws -> ChatResponse {
        // Thread-safe implementation
    }
    
    nonisolated public func stream(_ request: ChatRequest) -> AsyncStream<ChatDelta> {
        // Non-isolated streaming for better performance
    }
}
```

**Key Features:**
- **Thread safety**: Actor isolation prevents data races
- **Async/await integration**: Natural Swift concurrency patterns
- **Non-isolated streaming**: Streaming method is non-isolated for performance
- **Resource management**: Proper URLSession lifecycle management

### Type-Safe Configuration System

Configuration parameters use a protocol-based approach that applies the Command pattern:

```swift
public protocol ChatConfigParameter {
    func apply(to request: inout ChatRequest)
}

public struct Temperature: ChatConfigParameter {
    public let value: Double
    
    public init(_ value: Double) throws {
        guard (0.0...2.0).contains(value) else {
            throw LLMError.invalidValue("Temperature must be between 0.0 and 2.0, got \\(value)")
        }
        self.value = value
    }
    
    public func apply(to request: inout ChatRequest) {
        request.temperature = value
    }
}
```

**Advantages:**
- **Validation at initialization**: Invalid values are rejected immediately
- **Composability**: Parameters can be mixed and matched freely
- **Extensibility**: Easy to add custom parameters
- **Type safety**: Compile-time checking of parameter types

## JSON Serialization Strategy

The package handles JSON serialization carefully to bridge Swift's type system with OpenAI's API format.

### CodingKeys Mapping

Swift camelCase properties are mapped to OpenAI's snake_case format:

```swift
private enum CodingKeys: String, CodingKey {
    case model
    case messages
    case temperature
    case maxTokens = "max_tokens"
    case topP = "top_p"
    case frequencyPenalty = "frequency_penalty"
    case presencePenalty = "presence_penalty"
    case stream
    case n
    case logitBias = "logit_bias"
    case user
    case stop
    case tools
}
```

### Heterogeneous Message Encoding

Since messages conform to the `ChatMessage` protocol, special handling is needed for JSON serialization:

```swift
private struct AnyEncodableMessage: Encodable {
    private let message: any ChatMessage
    
    init(_ message: any ChatMessage) {
        self.message = message
    }
    
    func encode(to encoder: Encoder) throws {
        try message.encode(to: encoder)
    }
}
```

This wrapper allows arrays of different message types to be encoded correctly.

## Error Handling Patterns

The package uses a comprehensive error handling strategy with custom error types:

```swift
public enum LLMError: Error, Equatable {
    case invalidURL
    case encodingFailed(String)
    case networkError(String)
    case decodingFailed(String)
    case serverError(statusCode: Int, message: String?)
    case rateLimit
    case invalidResponse
    case invalidValue(String)
    case missingBaseURL
    case missingModel
}
```

**Error Handling Strategy:**
- **Specific error types**: Each failure mode has a dedicated case
- **Descriptive messages**: Error context is preserved and propagated
- **Equatable conformance**: Enables testing and comparison
- **Sendable compliance**: Safe for concurrent environments

## Streaming Implementation

The streaming functionality uses AsyncStream to provide real-time response processing:

```swift
nonisolated public func stream(_ request: ChatRequest) -> AsyncStream<ChatDelta> {
    return AsyncStream { continuation in
        Task { @Sendable in
            // Handle Server-Sent Events parsing
            var buffer = ""
            for try await byte in asyncBytes {
                buffer.append(Character(UnicodeScalar(byte)))
                
                while let eventRange = buffer.range(of: "\\n\\n") {
                    let event = String(buffer[..<eventRange.lowerBound])
                    buffer.removeSubrange(..<eventRange.upperBound)
                    
                    // Process SSE data lines
                    for line in event.components(separatedBy: "\\n") {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))
                            if data == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            // Decode and yield delta
                        }
                    }
                }
            }
        }
    }
}
```

**Streaming Features:**
- **Server-Sent Events parsing**: Proper SSE protocol handling
- **Incremental processing**: Yields deltas as they arrive
- **Error resilience**: Continues processing even if individual deltas fail
- **Resource cleanup**: Proper stream termination and resource management

## Extensibility Points

### Custom Messages

The protocol-oriented design allows for easy extension with custom message types:

```swift
struct ImageMessage: ChatMessage {
    let role: Role = .user
    let content: [ContentPart]
    
    struct ContentPart: Codable {
        let type: String
        let text: String?
        let imageURL: ImageURL?
        
        struct ImageURL: Codable {
            let url: String
        }
    }
}
```

### Custom Parameters

New configuration parameters can be added by conforming to `ChatConfigParameter`:

```swift
struct CustomTimeout: ChatConfigParameter {
    let value: TimeInterval
    
    func apply(to request: inout ChatRequest) {
        // Custom application logic
    }
}
```

## Performance Considerations

### Compile-Time Optimization

- **@inlinable methods**: Result builder methods are marked `@inlinable` for performance
- **Value types**: Extensive use of structs for memory efficiency
- **Copy-on-write**: Large collections use efficient copying strategies

### Runtime Optimization

- **Actor isolation**: Minimal actor hopping for better performance
- **Lazy evaluation**: Configuration parameters are applied only when needed
- **Resource pooling**: URLSession reuse for connection efficiency

## Swift 6 Compliance

The entire package is designed for Swift 6's strict concurrency model:

- **Sendable conformance**: All types are marked `Sendable` where appropriate
- **Actor isolation**: Proper isolation boundaries for thread safety
- **Data races prevention**: No shared mutable state without proper synchronization

This ensures the package works seamlessly in Swift 6's strict concurrency mode while maintaining backward compatibility with earlier Swift versions.
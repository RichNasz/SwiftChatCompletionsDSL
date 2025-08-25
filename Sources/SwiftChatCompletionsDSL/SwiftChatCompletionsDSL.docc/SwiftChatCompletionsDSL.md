# SwiftChatCompletionsDSL

A declarative Swift DSL for building type-safe, readable chat completion requests with OpenAI-compatible APIs.

## Overview

SwiftChatCompletionsDSL transforms complex LLM API interactions into clean, declarative Swift code. Using result builders and Swift's type system, you can build chat completion requests that are both safe and expressive.

```swift
let request = try ChatRequest(model: "gpt-4") {
    try Temperature(0.7)
    try MaxTokens(150)
} messages: {
    TextMessage(role: .system, content: "You are a helpful assistant.")
    TextMessage(role: .user, content: "Explain async/await in Swift.")
}

let response = try await client.complete(request)
```

## Key Benefits

### Type Safety
Compile-time validation prevents runtime errors. Parameter validation ensures values are within valid ranges, and Swift's type system catches configuration mistakes before they reach production.

### Declarative Syntax
Express your intent clearly using result builders. The DSL reads like natural language, making code self-documenting and easier to maintain.

### Swift Concurrency
Built from the ground up with async/await and actors. Non-blocking operations and thread-safe client design ensure excellent performance in concurrent environments.

### Streaming Support
Real-time response processing with AsyncStream. Handle streaming responses naturally using Swift's async iteration.

## Getting Started

### Installation

Add SwiftChatCompletionsDSL to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/RichNasz/SwiftChatCompletionsDSL", from: "1.0.0")
]
```

### Basic Example

```swift
import SwiftChatCompletionsDSL

// Create a client
let client = try LLMClient(
    baseURL: "https://api.openai.com/v1/chat/completions",
    apiKey: "your-api-key"
)

// Build and send a request
let request = try ChatRequest(model: "gpt-4") {
    try Temperature(0.7)
} messages: {
    TextMessage(role: .user, content: "Hello, world!")
}

let response = try await client.complete(request)
print(response.choices.first?.message.content ?? "No response")
```

## Learn More About

### Core Concepts

- <doc:DSL> - Learn about Domain Specific Languages and how to use SwiftChatCompletionsDSL effectively
- <doc:Architecture> - Understanding the technical design and patterns used in the package
- <doc:Usage> - Practical examples and patterns for real-world applications

### Advanced Topics

- **Custom Messages** - Extend the DSL with your own message types for multimodal content
- **Configuration Parameters** - Create custom configuration options for specialized use cases
- **Error Handling** - Robust error handling patterns with detailed error information
- **Conversation Management** - Building stateful conversations with history management

## Topics

### Essentials

- ``LLMClient``
- ``ChatRequest``
- ``ChatResponse``
- ``TextMessage``

### Building Requests

- ``ChatBuilder``
- ``ChatConfigBuilder``
- ``ChatMessage``
- ``ChatConfigParameter``

### Configuration Parameters

- ``Temperature``
- ``MaxTokens``
- ``TopP``
- ``FrequencyPenalty``
- ``PresencePenalty``
- ``N``
- ``User``
- ``Stop``
- ``LogitBias``

### Tool Support

- ``Tool``
- ``Tools``

### Conversation Management

- ``ChatConversation``

### Streaming

- ``ChatDelta``

### Error Handling

- ``LLMError``

### Core Types

- ``Role``

## See Also

### Articles

- <doc:DSL>: **Essential reading** - A beginner-friendly guide to Domain Specific Languages that makes SwiftChatCompletionsDSL accessible to developers at all experience levels. Learn what DSLs are, why they matter, and how to use them effectively.

- <doc:Architecture>: Deep dive into the technical architecture, including result builder patterns, actor-based concurrency, type-safe configuration systems, and extensibility points.

- <doc:Usage>: Comprehensive usage examples covering everything from basic requests to advanced conversation management, streaming responses, and integration with different LLM providers.

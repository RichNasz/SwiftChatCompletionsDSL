# Specification for SwiftChatCompletionsDSL

## Overview
The **SwiftChatCompletionsDSL** is an embedded Swift DSL that simplifies communication with LLM inference servers supporting OpenAI-compatible Chat Completions endpoints. It abstracts HTTP requests, JSON serialization, authentication, and error handling into a declarative, type-safe interface, supporting both non-streaming and streaming responses. Users must provide the complete endpoint URL (`baseURL`) when initializing the client and the `model` in every request, ensuring compatibility with varied servers (e.g., `https://api.openai.com/v1/chat/completions`, `https://your-llm-server.com/custom/endpoint`). Optional parameters are specified via a `@ChatConfigBuilder` block, allowing users to include only desired parameters (e.g., `Temperature(0.7)`, `MaxTokens(100)`) with minimal code, using a result builder for declarative syntax.

To support conversation history, the DSL is extended with:
- An additional initializer for `ChatRequest` that accepts a pre-built array of messages (`[any ChatMessage]`), enabling users to pass existing conversation history directly without relying on the result builder.
- A new `ChatConversation` struct for managing persistent conversation history, with methods to append messages and generate `ChatRequest`s. This facilitates stateful interactions, where history can be built incrementally across multiple requests.

## Goals
- **Explicit Configuration**: Require `baseURL` (full endpoint URL) in client initialization and `model` in every request, without defaults or path appending.
- **Optional Parameters**: Allow any combination of optional parameters (`temperature`, `maxTokens`, `topP`, `frequencyPenalty`, `presencePenalty`, `n`, `logitBias`, `user`) via a `@ChatConfigBuilder` block, minimizing user code while ensuring type safety.
- **Declarative API**: Use result builders for messages (`@ChatBuilder`) and configuration (`@ChatConfigBuilder`), supporting control flow (e.g., `if`, `for`).
- **Conversation History Support**: Enable sending arrays of messages representing multi-turn conversations, with utilities for building and maintaining history.
- **Type Safety**: Enforce roles, parameters, and responses at compile time using enums, protocols, and structs.
- **Concurrency**: Use `async`/`await` and actors for non-blocking calls; apply `nonisolated` for streaming method flexibility.
- **Performance**: Use value types (structs) and compile-time transformations (e.g., result builders) to minimize runtime overhead.
- **Extensibility**: Support custom messages or endpoints via protocols/extensions.
- **Error Handling**: Propagate errors with a custom error enum using `throws`.

## Requirements
- **Swift Version**: 6.1+ (enable for trailing commas, `nonisolated`, improved type inference, e.g., for task groups).
- **Dependencies**: None; use only Foundation (`URLSession` for networking, `Codable` for JSON serialization).
- **API Compatibility**: Align with OpenAI Chat Completions JSON format for requests and responses (camelCase internally, snake_case in JSON via `CodingKeys`).
- **Testing**: Support Swift Testing for async validation (e.g., `#expect` with concurrency traits).
- **URL Handling**: Treat `baseURL` as the complete endpoint URL provided by the user, without modification.
- **Minimum OS Versions**: macOS 12.0, iOS 15.0 (required for AsyncStream and URLSession.data(for:) availability).
- **Date Context**: Spec aligns with usage on August 22, 2025, ensuring modern Swift practices.

## Core Components

### 1. Enums
- **Role**: Defines message roles, mapped to JSON strings.
  - Signature: `enum Role: String, Codable { case system, user, assistant, tool }`
  - Purpose: Represents message roles (`system`, `user`, `assistant`, `tool` for future extensions like tool calls).
  - JSON: Encodes as strings (e.g., `"system"`).

- **LLMError**: Custom errors for API failures.
  - Signature: `enum LLMError: Error { case invalidURL, encodingFailed(String), networkError(String), decodingFailed(String), serverError(statusCode: Int, message: String?), rateLimit, invalidResponse, invalidValue(String), missingBaseURL, missingModel }`
  - Purpose: Handles errors like invalid URLs, JSON failures, server errors (e.g., HTTP 429 for rate limits), missing required fields, and invalid parameter values. The `invalidValue(String)` case is specifically for configuration parameter validation with descriptive error messages.

### 2. Protocols
- **ChatMessage**: Extensible protocol for messages.
  - Signature: `protocol ChatMessage: Encodable { var role: Role { get }; var content: any Encodable { get } }`
  - Purpose: Defines messages with a role and content (text or future multimodal types like images).
  - JSON: Encodes to `{ "role": String, "content": Any }`.

- **ChatConfigParameter**: Protocol for configuration parameters.
  - Signature: `protocol ChatConfigParameter { func apply(to request: inout ChatRequest) }`
  - Purpose: Allows parameter structs (e.g., `Temperature`) to modify `ChatRequest` fields during initialization.

### 3. Structs
- **TextMessage**: Basic text-based message implementing `ChatMessage`.
  - Signature: `struct TextMessage: ChatMessage { let role: Role; let content: String }`
  - JSON: Encodes to `{ "role": String, "content": String }` with `CodingKeys` for `role`, `content`.
  - Purpose: Represents a single text message (e.g., system prompt or user input).

- **Configuration Structs**: For optional parameters, each implementing `ChatConfigParameter`.
  - **Temperature**:
    - Signature: `struct Temperature: ChatConfigParameter { let value: Double; init(_ value: Double) throws; func apply(to request: inout ChatRequest) }`
    - Validation: Throws `LLMError.invalidValue(String)` if `value` not in `0.0...2.0`.
    - Applies: Sets `request.temperature = value`.
  - **MaxTokens**:
    - Signature: `struct MaxTokens: ChatConfigParameter { let value: Int; init(_ value: Int) throws; func apply(to request: inout ChatRequest) }`
    - Validation: Throws `LLMError.invalidValue(String)` if `value <= 0`.
    - Applies: Sets `request.maxTokens = value`.
  - **TopP**:
    - Signature: `struct TopP: ChatConfigParameter { let value: Double; init(_ value: Double) throws; func apply(to request: inout ChatRequest) }`
    - Validation: Throws `LLMError.invalidValue(String)` if `value` not in `0.0...1.0`.
    - Applies: Sets `request.topP = value`.
  - **FrequencyPenalty**:
    - Signature: `struct FrequencyPenalty: ChatConfigParameter { let value: Double; init(_ value: Double) throws; func apply(to request: inout ChatRequest) }`
    - Validation: Throws `LLMError.invalidValue(String)` if `value` not in `-2.0...2.0`.
    - Applies: Sets `request.frequencyPenalty = value`.
  - **PresencePenalty**:
    - Signature: `struct PresencePenalty: ChatConfigParameter { let value: Double; init(_ value: Double) throws; func apply(to request: inout ChatRequest) }`
    - Validation: Throws `LLMError.invalidValue(String)` if `value` not in `-2.0...2.0`.
    - Applies: Sets `request.presencePenalty = value`.
  - **N**:
    - Signature: `struct N: ChatConfigParameter { let value: Int; init(_ value: Int) throws; func apply(to request: inout ChatRequest) }`
    - Validation: Throws `LLMError.invalidValue(String)` if `value <= 0`.
    - Applies: Sets `request.n = value`.
  - **LogitBias**:
    - Signature: `struct LogitBias: ChatConfigParameter { let value: [String: Int]; init(_ value: [String: Int]); func apply(to request: inout ChatRequest) }`
    - Validation: None (assumes valid dictionary).
    - Applies: Sets `request.logitBias = value`.
  - **User**:
    - Signature: `struct User: ChatConfigParameter { let value: String; init(_ value: String) throws; func apply(to request: inout ChatRequest) }`
    - Validation: Throws `LLMError.invalidValue(String)` if `value` is empty.
    - Applies: Sets `request.user = value`.
  - **Stop** (additional param):
    - Signature: `struct Stop: ChatConfigParameter { let value: [String]; init(_ value: [String]) throws; func apply(to request: inout ChatRequest) }`
    - Validation: Throws `LLMError.invalidValue(String)` if array is empty or contains invalid strings.
    - Applies: Sets `request.stop = value`.
  - **Tools** (additional param for future tool calls):
    - Signature: `struct Tools: ChatConfigParameter { let value: [Tool]; init(_ value: [Tool]); func apply(to request: inout ChatRequest) }`
    - Validation: None, but assume `Tool` struct with name, description, parameters.
    - Applies: Sets `request.tools = value`.

- **ChatRequest**: Represents the API request.
  - Signature:
    ```swift
    struct ChatRequest: Encodable {
        let model: String
        let messages: [any ChatMessage]
        var temperature: Double?
        var maxTokens: Int?
        var topP: Double?
        var frequencyPenalty: Double?
        var presencePenalty: Double?
        let stream: Bool
        var n: Int?
        var logitBias: [String: Int]?
        var user: String?
        var stop: [String]?  // Additional
        var tools: [Tool]?  // Additional, with Tool struct

        init(
            model: String,
            stream: Bool = false,
            @ChatConfigBuilder config: () -> [ChatConfigParameter] = { [] },
            @ChatBuilder messages: () -> [any ChatMessage]
        ) throws

        init(
            model: String,
            stream: Bool = false,
            @ChatConfigBuilder config: () -> [ChatConfigParameter] = { [] },
            messages: [any ChatMessage]
        ) throws
    }
    ```
  - Initialization: 
    - Builder version: Builds messages via result builder.
    - Array version: Accepts pre-built array of messages for conversation history.
    - Both require non-empty `model`, throw `LLMError.missingModel` if empty. Apply config parameters via `apply(to:)` in a loop.
  - JSON: Encodes to OpenAI format with snake_case keys (e.g., `max_tokens`, `top_p`, `logit_bias`) using `CodingKeys`.
  - Purpose: Combines required `model`, `messages` (as array for history), optional `stream`, and config parameters.

- **ChatConversation**: Utility for managing conversation history.
  - Signature:
    ```swift
    struct ChatConversation {
        var history: [any ChatMessage]

        init(@ChatBuilder messages: () -> [any ChatMessage]) {
            self.history = messages()
        }

        init(history: [any ChatMessage] = []) {
            self.history = history
        }

        mutating func add(message: any ChatMessage) {
            history.append(message)
        }

        mutating func addUser(content: String) {
            add(TextMessage(role: .user, content: content))
        }

        mutating func addAssistant(content: String) {
            add(TextMessage(role: .assistant, content: content))
        }

        func request(
            model: String,
            stream: Bool = false,
            @ChatConfigBuilder config: () -> [ChatConfigParameter] = { [] },
            @ChatBuilder additionalMessages: () -> [any ChatMessage] = { [] }
        ) throws -> ChatRequest {
            let allMessages = history + additionalMessages()
            return try ChatRequest(model: model, stream: stream, config: config, messages: allMessages)
        }
    }
    ```
  - Purpose: Maintains an array of messages as conversation history, with convenience methods for adding user/assistant messages. Generates `ChatRequest` using the history plus optional additional messages.

- **ChatResponse**: For non-streaming responses.
  - Signature:
    ```swift
    struct ChatResponse: Decodable {
        let id: String
        let object: String
        let created: Int
        let model: String
        let choices: [Choice]
        let usage: Usage?
        struct Choice: Decodable { let index: Int; let message: Message; let finishReason: String? }
        struct Message: Decodable { let role: Role; let content: String }
        struct Usage: Decodable { let promptTokens: Int; let completionTokens: Int; let totalTokens: Int }
    }
    ```
  - JSON: Decodes from OpenAI format (e.g., `finish_reason`, `prompt_tokens`).

- **ChatDelta**: For streaming responses.
  - Signature:
    ```swift
    struct ChatDelta: Decodable {
        let choices: [DeltaChoice]
        struct DeltaChoice: Decodable {
            let index: Int
            let delta: Delta
            let finishReason: String?
            struct Delta: Decodable { let content: String?; let role: Role? }
        }
    }
    ```
  - JSON: Decodes SSE chunks with `delta.content` for incremental text.

### 4. Result Builders
- **ChatBuilder**: Composes message sequences.
  - Signature:
    ```swift
    @resultBuilder
    struct ChatBuilder {
        static func buildBlock(_ components: any ChatMessage...) -> [any ChatMessage]
        static func buildEither(first: [any ChatMessage]) -> [any ChatMessage]
        static func buildEither(second: [any ChatMessage]) -> [any ChatMessage]
        static func buildOptional(_ component: [any ChatMessage]?) -> [any ChatMessage]
        static func buildArray(_ components: [[any ChatMessage]]) -> [any ChatMessage]
        static func buildLimitedAvailability(_ component: [any ChatMessage]) -> [any ChatMessage]
    }
    ```
  - Purpose: Enables declarative message blocks with control flow (e.g., `if`, `for`).

- **ChatConfigBuilder**: Composes configuration parameters.
  - Signature:
    ```swift
    @resultBuilder
    struct ChatConfigBuilder {
        static func buildBlock(_ components: ChatConfigParameter...) -> [ChatConfigParameter]
        static func buildEither(first: [ChatConfigParameter]) -> [ChatConfigParameter]
        static func buildEither(second: [ChatConfigParameter]) -> [ChatConfigParameter]
        static func buildOptional(_ component: [ChatConfigParameter]?) -> [ChatConfigParameter]
        static func buildArray(_ components: [[ChatConfigParameter]]) -> [ChatConfigParameter]
        static func buildLimitedAvailability(_ component: [ChatConfigParameter]) -> [ChatConfigParameter]
    }
    ```
  - Purpose: Enables declarative configuration blocks with control flow.

### 5. Actor: LLMClient
- Signature:
  ```swift
  actor LLMClient {
      init(baseURL: String, apiKey: String, sessionConfiguration: URLSessionConfiguration = .default) throws
      func complete(_ request: ChatRequest) async throws -> ChatResponse
      nonisolated func stream(_ request: ChatRequest) -> AsyncStream<ChatDelta>
  }
  ```
- Purpose: Manages API calls with thread-safe state (e.g., `private let baseURL`, `private let apiKey`, `private let session: URLSession`).
- Initialization: Takes `baseURL` (complete endpoint), `apiKey`, and optional `sessionConfiguration` (defaults to `URLSessionConfiguration.default`). Throws `LLMError.missingBaseURL` if invalid/empty. Creates `URLSession` with the provided configuration.
- Methods:
  - `complete`: Sends non-streaming POST request to `baseURL` with `Authorization: Bearer <apiKey>` and `Content-Type: application/json`. Throws `LLMError` on failure (e.g., HTTP 429 for rateLimit).
  - `stream`: Returns `AsyncStream<ChatDelta>` for streaming, setting `Accept: text/event-stream`. Parses Server-Sent Events (SSE): Split string by '\n\n', process lines starting with 'data: ', trim prefix, decode JSON to `ChatDelta` if not '[DONE]', yield deltas, finish stream on '[DONE]' or error. Handle multi-line chunks and ignore non-data lines. Propagate errors via `continuation.finish(throwing:)`.
- Notes: Use `URLSession` for networking, `JSONEncoder`/`JSONDecoder` for serialization. `nonisolated` stream method for usability without `await`. If no custom `sessionConfiguration` provided, use `URLSession.shared`.

## Usage Examples
1. **Non-Streaming** (custom server):
   ```swift
   let client = try LLMClient(baseURL: "https://your-llm-server.com/custom/chat/endpoint", apiKey: "sk-...")
   do {
       let response = try await client.complete(
           try ChatRequest(model: "custom-model") {
               Temperature(0.7)
               MaxTokens(150)
               if someCondition {
                   TopP(0.9)
               },
           } messages: {
               TextMessage(role: .system, content: "You are a coding assistant."),
               TextMessage(role: .user, content: "Explain Swift concurrency."),
           }
       )
       print(response.choices.first?.message.content ?? "No response")
   } catch {
       print("Error: \(error)")
   }
   ```
   - Notes: Specifies complete `baseURL`, required `model`. Config block includes only desired parameters with control flow. Trailing commas supported (Swift 6.1+).

2. **Streaming** (OpenAI):
   ```swift
   let client = try LLMClient(baseURL: "https://api.openai.com/v1/chat/completions", apiKey: "sk-...")
   let stream = client.stream(
       try ChatRequest(model: "gpt-4o", stream: true) {
           Temperature(0.8)
           MaxTokens(200)
           User("user123")
       } messages: {
           TextMessage(role: .user, content: "Write a poem."),
       }
   )
   for await delta in stream {
       if let content = delta.choices.first?.delta.content {
           print(content, terminator: "")
       }
   }
   ```
   - Notes: Sets `stream: true` in `ChatRequest`. Config block specifies subset of parameters. Processes SSE chunks incrementally.

3. **Invalid Parameter Example** (expect throw):
   ```swift
   do {
       _ = try Temperature(3.0)  // Throws LLMError.invalidValue
   } catch {
       print(error)
   }
   ```

4. **Extension Example** (custom parameter):
   ```swift
   struct Stop: ChatConfigParameter {
       let value: [String]
       init(_ value: [String]) throws {
           guard !value.isEmpty else { throw LLMError.invalidValue("Stop sequences cannot be empty") }
           self.value = value
       }
       func apply(to request: inout ChatRequest) {
           request.stop = value
       }
   }
   let request = try ChatRequest(model: "model") {
       Stop(["\n"])
   } messages: { /* ... */ }
   ```

5. **Conversation History with Array Init**:
   ```swift
   let history: [any ChatMessage] = [
       TextMessage(role: .system, content: "You are helpful."),
       TextMessage(role: .user, content: "Hello."),
       TextMessage(role: .assistant, content: "Hi! How can I help?")
   ]
   let request = try ChatRequest(model: "gpt-4o", messages: history)
   // Use with client.complete or stream
   ```

6. **Conversation History with ChatConversation**:
   ```swift
   var conversation = ChatConversation()
   conversation.addUser(content: "What's the weather?")
   // After receiving response, add assistant message
   conversation.addAssistant(content: "It's sunny.")
   conversation.addUser(content: "What's the temperature?")
   let request = try conversation.request(model: "gpt-4o") {
       Temperature(0.5)
   } additionalMessages: {
       // Optional additional messages
   }
   // Send request via client
   ```

7. **Custom URLSessionConfiguration**:
   ```swift
   let config = URLSessionConfiguration.default
   config.timeoutIntervalForRequest = 30.0
   let client = try LLMClient(baseURL: "https://api.openai.com/v1/chat/completions", apiKey: "sk-...", sessionConfiguration: config)
   // Use client as usual
   ```

## Extensibility
- **Custom Messages**: Add `ChatMessage` conformances (e.g., `ImageMessage` for vision models). For multimodal, allow `content` as arrays (e.g., `[ { "type": "text", "text": String }, { "type": "image_url", "image_url": { "url": String } } ]`). Example:
  ```swift
  struct ImageMessage: ChatMessage {
      let role: Role = .user
      let content: [AnyEncodable] = [ ["type": "image_url", "image_url": ["url": "https://example.com/image.jpg"]] ]
  }
  ```
- **Custom Parameters**: Add `ChatConfigParameter` conformances (e.g., `StopSequence`).
- **Client Extensions**: Extend `LLMClient` for additional endpoints (e.g., model listing).

## Implementation Notes
- **Project Structure**: Generate as a Swift Package Manager package with structure: Package.swift (target 'SwiftChatCompletionsDSL'), ./Sources/SwiftChatCompletionsDSL/ containing all files. Make types public where appropriate (e.g., `public struct ChatRequest`). No tests or examples in generated code; focus on library sources.
- **Access Levels**: Mark client-facing types/methods as `public` (e.g., `public actor LLMClient`, `public struct ChatRequest`). Use `private` for internal state (e.g., `private let baseURL`). Ensure `@resultBuilder` and protocols are public.
- **URL Handling**: Use `baseURL` as complete endpoint; validate at `LLMClient` init.
- **Validation**: Enforce non-empty `baseURL` and `model`. Configuration structs validate ranges (e.g., `Temperature` 0.0–2.0, `TopP` 0.0–1.0).
- **JSON**: Use `CodingKeys` for snake_case (e.g., `max_tokens`, `top_p`). Use `nestedUnkeyedContainer` for encoding `[any ChatMessage]` arrays.
- **Swift 6.1+**: Leverage trailing commas, `nonisolated`, async type inference. Use `@inlinable` on builder methods for optimization.
- **Concurrency & Sendable**: All types must conform to `Sendable` for Swift 6 strict concurrency. This includes `ChatRequest`, `ChatMessage`, `Role`, `LLMError`, and all response types. For `LLMError`, use string descriptions instead of Error objects to maintain `Equatable` conformance.
- **Result Builder Configuration**: Config closures must be marked as `() throws -> [ChatConfigParameter]` to allow throwing parameter initialization within the DSL.
- **Platform Requirements**: Set minimum platforms to `macOS(.v12), iOS(.v15)` in Package.swift for `AsyncStream` and `URLSession.data(for:)` availability.
- **Streaming**: Parse SSE, handling `data: [DONE]` and errors. Each chunk is valid JSON decoding to `ChatDelta`. Use `@Sendable` closures and capture local values to avoid actor isolation issues.
- **Tool Support**: For `Tool.Function.parameters`, use `[String: String]` instead of `[String: Any]` to maintain `Sendable` conformance. This simplifies JSON schema definitions while maintaining type safety.
- **Testing**: Support Swift Testing with `#expect` for async tests. Key considerations:
  - Use array-based message initialization for simpler test syntax
  - Mock URLSession with URLProtocol for network tests
  - Test parameter validation with proper error types
  - Tests should be stored in ./Tests/SwiftChatCompletionsDSLTests folder
- **Docs**: Add SwiftDoc comments for all public APIs.
- **Edge Cases**: Handle empty messages, rate limits (429), invalid JSON, server errors.

## Required Tests
These tests validate key DSL behaviors and must pass for the implementation to conform to the spec. Use the Swift Testing framework with `#expect` for assertions, supporting async and throwing scenarios. Tests should be placed in a separate test target (e.g., SwiftChatCompletionsDSLTests) and use mocks where necessary (e.g., `URLProtocol` for network).

1. **ChatRequest Initialization and Configuration**:
   ```swift
   @Test func testChatRequestConfig() {
       let request = try ChatRequest(model: "test-model") {
           Temperature(0.7)
           MaxTokens(100)
       } messages: {
           TextMessage(role: .user, content: "Test message")
       }
       #expect(request.model == "test-model")
       #expect(request.temperature == 0.7)
       #expect(request.maxTokens == 100)
       #expect(request.messages.count == 1)
       #expect(request.messages.first?.content as? String == "Test message")
   }
   ```

2. **Invalid Parameter Validation**:
   ```swift
   @Test func testInvalidTemperature() {
       #expect(throws: LLMError.invalidValue) {
           try Temperature(3.0)
       }
   }
   ```

3. **Conversation History with ChatConversation**:
   ```swift
   @Test func testChatConversationHistory() {
       var conversation = ChatConversation()
       conversation.addUser(content: "Hello")
       conversation.addAssistant(content: "Hi there")
       let request = try conversation.request(model: "test-model")
       #expect(request.messages.count == 2)
       #expect(request.messages[0].role == .user)
       #expect(request.messages[1].role == .assistant)
   }
   ```

4. **Array-Based ChatRequest Init**:
   ```swift
   @Test func testArrayMessagesInit() {
       let history: [any ChatMessage] = [TextMessage(role: .user, content: "Query")]
       let request = try ChatRequest(model: "test-model", messages: history)
       #expect(request.messages.count == 1)
   }
   ```

5. **LLMClient Initialization Validation**:
   ```swift
   @Test func testClientMissingBaseURL() {
       #expect(throws: LLMError.missingBaseURL) {
           try LLMClient(baseURL: "", apiKey: "key")
       }
   }
   ```

6. **Streaming SSE Parsing (Async)**:
   ```swift
   @Test func testStreamParsing() async {
       // Mock URLSession with URLProtocol to simulate SSE response: "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\ndata: [DONE]"
       // Arrange mock request and client
       let request = try ChatRequest(model: "test-model", stream: true, messages: [])
       let stream = client.stream(request)
       var contents: [String] = []
       for await delta in stream {
           if let content = delta.choices.first?.delta.content {
               contents.append(content)
           }
       }
       #expect(contents == ["Hello"]) // Assert parsed content
   }
   ```

7. **Multimodal Extension**:
   ```swift
   @Test func testImageMessage() {
       struct ImageMessage: ChatMessage {
           let role: Role = .user
           let content: [AnyEncodable] = [ ["type": "image_url", "image_url": ["url": "https://example.com/image.jpg"]] ]
       }
       let message = ImageMessage()
       #expect(message.role == .user)
   }
   ```

8. **Edge Case: Empty Messages**:
   ```swift
   @Test func testEmptyMessages() {
       let request = try ChatRequest(model: "test-model", messages: [])
       #expect(request.messages.isEmpty)
   }
   ```

These tests cover essential functionality, errors, and extensibility. Implement additional tests for full coverage if needed.

This spec provides a clear blueprint for an LLM code generator to produce a Swift 6.1+ package, ensuring a declarative, type-safe, and flexible DSL for OpenAI-compatible LLM servers.

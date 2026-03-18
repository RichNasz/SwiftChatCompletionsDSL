# Specification for SwiftChatCompletionsDSL

## Overview
The **SwiftChatCompletionsDSL** is an embedded Swift DSL that simplifies communication with LLM inference servers supporting OpenAI-compatible Chat Completions endpoints. It abstracts HTTP requests, JSON serialization, authentication, and error handling into a declarative, type-safe interface, supporting both non-streaming and streaming responses. Users must provide the complete endpoint URL (`baseURL`) when initializing the client and the `model` in every request, ensuring compatibility with varied servers (e.g., `https://api.openai.com/v1/chat/completions`, `https://your-llm-server.com/custom/endpoint`). Optional parameters are specified via a `@ChatConfigBuilder` block, allowing users to include only desired parameters (e.g., `Temperature(0.7)`, `MaxTokens(100)`) with minimal code, using a result builder for declarative syntax.

To support conversation history, the DSL is extended with:
- An additional initializer for `ChatRequest` that accepts a pre-built array of messages (`[any ChatMessage]`), enabling users to pass existing conversation history directly without relying on the result builder.
- A new `ChatConversation` struct for managing persistent conversation history, with methods to append messages and generate `ChatRequest`s. This facilitates stateful interactions, where history can be built incrementally across multiple requests.

For tool calling and agent capabilities, see [ToolCalling.md](ToolCalling.md) and [ToolSupportSpec.md](ToolSupportSpec.md).

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
- **Swift Version**: 6.2+ (enable for trailing commas, `nonisolated`, improved type inference, e.g., for task groups).
- **Dependencies**: None; use only Foundation (`URLSession` for networking, `Codable` for JSON serialization).
- **API Compatibility**: Align with OpenAI Chat Completions JSON format for requests and responses (camelCase internally, snake_case in JSON via `CodingKeys`).
- **Testing**: Support Swift Testing for async validation (e.g., `#expect` with concurrency traits).
- **URL Handling**: Treat `baseURL` as the complete endpoint URL provided by the user, without modification.
- **Minimum OS Versions**: macOS 13.0, iOS 16.0 (required for AsyncStream and URLSession.bytes(for:) availability).

---

## Core Components

### 1. Type Aliases
- **ChatMessages**: Convenience type alias for message arrays.
  - Signature: `typealias ChatMessages = [any ChatMessage]`
  - Purpose: Provides a shorter, more readable type for message arrays throughout the codebase.

### 2. Enums
- **Role**: Defines message roles, mapped to JSON strings.
  - Signature: `enum Role: String, Codable { case system, user, assistant, tool }`
  - Purpose: Represents message roles (`system`, `user`, `assistant`, `tool` for future extensions like tool calls).
  - JSON: Encodes as strings (e.g., `"system"`).

- **LLMError**: Custom errors for API failures.
  - Signature: `enum LLMError: Error, Equatable { case invalidURL, encodingFailed(String), networkError(String), decodingFailed(String), serverError(statusCode: Int, message: String?), rateLimit, invalidResponse, invalidValue(String), missingBaseURL, missingModel, maxIterationsExceeded(Int), unknownTool(String), toolExecutionFailed(toolName: String, message: String) }`
  - Purpose: Handles errors like invalid URLs, JSON failures, server errors (e.g., HTTP 429 for rate limits), missing required fields, invalid parameter values, and tool calling errors. Conforms to `Equatable` (uses `String` descriptions rather than nested `Error` objects to maintain this).
  - **Error Cases**:
    - `invalidURL`: Base URL could not be converted to a valid URL
    - `encodingFailed(String)`: JSON encoding of the request failed
    - `networkError(String)`: Network-level errors (connection failed, timeout, DNS failure)
    - `decodingFailed(String)`: JSON decoding of the response failed
    - `serverError(statusCode: Int, message: String?)`: HTTP error responses (4xx, 5xx)
    - `rateLimit`: HTTP 429 rate limiting error
    - `invalidResponse`: Response format was unexpected or invalid
    - `invalidValue(String)`: Configuration parameter validation failed
    - `missingBaseURL`: Empty or missing base URL in client initialization
    - `missingModel`: Empty or missing model in request
    - `maxIterationsExceeded(Int)`: Tool-calling loop exceeded maximum iterations (see [ToolCalling.md](ToolCalling.md))
    - `unknownTool(String)`: Tool name not found in registered handlers (see [ToolCalling.md](ToolCalling.md))
    - `toolExecutionFailed(toolName: String, message: String)`: Tool handler threw an error during execution (see [ToolCalling.md](ToolCalling.md))
  - **Usage Example**:
    ```swift
    do {
        let response = try await client.complete(request)
        print(response.firstContent ?? "No response")
    } catch LLMError.rateLimit {
        print("Rate limited - wait before retrying")
    } catch LLMError.serverError(let statusCode, let message) {
        print("Server error \(statusCode): \(message ?? "Unknown")")
    } catch LLMError.networkError(let description) {
        print("Network error: \(description)")
    } catch LLMError.invalidValue(let message) {
        print("Invalid parameter: \(message)")
    } catch {
        print("Error: \(error)")
    }
    ```

### 3. Protocols
- **ChatMessage**: Extensible protocol for messages.
  - Signature: `protocol ChatMessage: Encodable, Sendable { var role: Role { get } }`
  - Purpose: Defines messages with a role. Content structure is left to concrete implementations (e.g., `TextMessage` has `content: String`) to allow flexibility for different message types including multimodal content.
  - JSON: Concrete implementations encode their specific structure (e.g., `{ "role": String, "content": String }` for TextMessage).

- **ChatConfigParameter**: Protocol for configuration parameters.
  - Signature: `protocol ChatConfigParameter: Sendable { func apply(to request: inout ChatRequest) }`
  - Purpose: Allows parameter structs (e.g., `Temperature`) to modify `ChatRequest` fields during initialization. Requires `Sendable` conformance for Swift 6 strict concurrency safety.

### 4. Structs
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
  - **UserID** (formerly `User`):
    - Signature: `struct UserID: ChatConfigParameter { let value: String; init(_ value: String) throws; func apply(to request: inout ChatRequest) }`
    - Validation: Throws `LLMError.invalidValue(String)` if `value` is empty.
    - Applies: Sets `request.user = value`.
    - Note: Renamed from `User` to avoid conflict with the `User()` convenience message function.
  - **Stop** (additional param):
    - Signature: `struct Stop: ChatConfigParameter { let value: [String]; init(_ value: [String]) throws; func apply(to request: inout ChatRequest) }`
    - Validation: Throws `LLMError.invalidValue(String)` if array is empty or contains invalid strings.
    - Applies: Sets `request.stop = value`.
  - **Tools** (additional param for future tool calls):
    - Signature: `struct Tools: ChatConfigParameter { let value: [Tool]; init(_ value: [Tool]); func apply(to request: inout ChatRequest) }`
    - Validation: None, but assume `Tool` struct with name, description, parameters.
    - Applies: Sets `request.tools = value`.
  - **RequestTimeout**:
    - Signature: `struct RequestTimeout: ChatConfigParameter { let value: TimeInterval; init(_ value: TimeInterval) throws; func apply(to request: inout ChatRequest) }`
    - Validation: Throws `LLMError.invalidValue(String)` if `value` not in `10...900` seconds.
    - Applies: Sets `request.requestTimeout = value`.
    - Purpose: Controls individual HTTP request timeouts for server response.
  - **ResourceTimeout**:
    - Signature: `struct ResourceTimeout: ChatConfigParameter { let value: TimeInterval; init(_ value: TimeInterval) throws; func apply(to request: inout ChatRequest) }`
    - Validation: Throws `LLMError.invalidValue(String)` if `value` not in `30...3600` seconds.
    - Applies: Sets `request.resourceTimeout = value`.
    - Purpose: Controls complete resource loading timeout including connection, request, and data transfer.

- **Tool**: Defines a tool that the model can call.
  - Signature:
    ```swift
    struct Tool: Sendable, Encodable {
        let type: String  // defaults to "function"
        let function: Function

        init(type: String = "function", function: Function)

        struct Function: Sendable, Encodable {
            let name: String
            let description: String
            let parameters: JSONSchema

            init(name: String, description: String, parameters: JSONSchema)

            // Deprecated backward-compat init
            @available(*, deprecated)
            init(name: String, description: String, parameters: [String: String])
        }
    }
    ```
  - Purpose: Defines a callable tool with its function name, description, and JSON Schema parameters. The deprecated `[String: String]` init converts each key-value pair into a `.string(description:)` schema property.

- **ChatRequest**: Represents the API request.
  - Signature:
    ```swift
    struct ChatRequest: Encodable, Sendable {
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
        var stop: [String]?
        var tools: [Tool]?
        var toolChoice: ToolChoice?
        var requestTimeout: TimeInterval?  // HTTP request timeout (10-900s)
        var resourceTimeout: TimeInterval?  // Complete resource loading timeout (30-3600s)

        // 1. Builder messages + config
        init(
            model: String,
            stream: Bool = false,
            @ChatConfigBuilder config: () throws -> [ChatConfigParameter] = { [] },
            @ChatBuilder messages: () -> [any ChatMessage]
        ) throws

        // 2. Builder messages only (no config block)
        init(
            model: String,
            stream: Bool = false,
            @ChatBuilder messages: () -> [any ChatMessage]
        ) throws

        // 3. Array messages + config
        init(
            model: String,
            stream: Bool = false,
            @ChatConfigBuilder config: () throws -> [ChatConfigParameter] = { [] },
            messages: [any ChatMessage]
        ) throws

        // 4. With inline tools builder + builder messages
        init(
            model: String,
            stream: Bool = false,
            toolChoice: ToolChoice? = nil,
            @ChatConfigBuilder config: () throws -> [ChatConfigParameter] = { [] },
            @ToolsBuilder tools: () -> [Tool],
            @ChatBuilder messages: () -> [any ChatMessage]
        ) throws

        // 5. With inline tools builder + array messages
        init(
            model: String,
            stream: Bool = false,
            toolChoice: ToolChoice? = nil,
            @ChatConfigBuilder config: () throws -> [ChatConfigParameter] = { [] },
            @ToolsBuilder tools: () -> [Tool],
            messages: [any ChatMessage]
        ) throws
    }
    ```
  - Initialization:
    - Builder version: Builds messages via result builder.
    - Messages-only version (init #2): Convenience without config block, calls through to array init with empty config.
    - Array version: Accepts pre-built array of messages for conversation history.
    - Tools versions: Accept inline tool definitions via `@ToolsBuilder` and optional `toolChoice`.
    - All require non-empty `model`, throw `LLMError.missingModel` if empty. Apply config parameters via `apply(to:)` in a loop.
  - JSON: Encodes to OpenAI format with snake_case keys (e.g., `max_tokens`, `top_p`, `logit_bias`, `tool_choice`) using `CodingKeys`. `requestTimeout` and `resourceTimeout` are excluded from JSON encoding (used only for URLSession configuration).
  - Purpose: Combines required `model`, `messages` (as array for history), optional `stream`, config parameters, and optional tool definitions.

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
            add(message: TextMessage(role: .user, content: content))
        }

        mutating func addAssistant(content: String) {
            add(message: TextMessage(role: .assistant, content: content))
        }

        mutating func addSystem(content: String) {
            add(message: TextMessage(role: .system, content: content))
        }

        var lastMessageRole: Role? {
            history.last?.role
        }

        var messageCount: Int {
            history.count
        }

        mutating func clear() {
            history.removeAll()
        }

        mutating func addAssistantToolCalls(content: String?, toolCalls: [ToolCall]) {
            add(message: AssistantToolCallMessage(content: content, toolCalls: toolCalls))
        }

        mutating func addToolResult(toolCallId: String, content: String) {
            add(message: ToolResultMessage(toolCallId: toolCallId, content: content))
        }

        func request(
            model: String,
            stream: Bool = false,
            @ChatConfigBuilder config: () throws -> [ChatConfigParameter] = { [] },
            @ChatBuilder additionalMessages: () -> [any ChatMessage] = { [] }
        ) throws -> ChatRequest {
            let allMessages = history + additionalMessages()
            return try ChatRequest(model: model, stream: stream, config: config, messages: allMessages)
        }
    }
    ```
  - Purpose: Maintains an array of messages as conversation history, with convenience methods for adding user/assistant/system messages. Provides utility properties (`lastMessageRole`, `messageCount`) and methods (`clear()`) for history management. Generates `ChatRequest` using the history plus optional additional messages.

- **ChatResponse**: For non-streaming responses.
  - Signature:
    ```swift
    struct ChatResponse: Decodable, Sendable {
        let id: String
        let object: String
        let created: Int
        let model: String
        let choices: [Choice]
        let usage: Usage?
        struct Choice: Decodable, Sendable { let index: Int; let message: Message; let finishReason: String? }
        struct Message: Decodable, Sendable { let role: Role; let content: String; let toolCalls: [ToolCall]? }
        struct Usage: Decodable, Sendable { let promptTokens: Int; let completionTokens: Int; let totalTokens: Int }
    }
    ```
  - JSON: Decodes from OpenAI format (e.g., `finish_reason`, `prompt_tokens`, `tool_calls`).
  - Note: `Message` has a custom decoder — `content` uses `decodeIfPresent`, coalescing `null` to `""` so the type stays `String` (not `String?`) for backward compatibility when the model returns tool calls with null content.

- **ChatDelta**: For streaming responses.
  - Signature:
    ```swift
    struct ChatDelta: Decodable, Sendable {
        let choices: [DeltaChoice]
        struct DeltaChoice: Decodable, Sendable {
            let index: Int
            let delta: Delta
            let finishReason: String?
            struct Delta: Decodable, Sendable { let content: String?; let role: Role?; let toolCalls: [ToolCallDelta]? }
        }
    }
    ```
  - JSON: Decodes SSE chunks with `delta.content` for incremental text and `delta.tool_calls` for incremental tool call data.

- **Response Convenience Extensions**: Convenience properties for common access patterns.
  - **ChatResponse Extensions**:
    ```swift
    extension ChatResponse {
        var firstContent: String? { choices.first?.message.content }
        var firstFinishReason: String? { choices.first?.finishReason }
        var totalTokens: Int { usage?.totalTokens ?? 0 }
        var firstToolCalls: [ToolCall]? { choices.first?.message.toolCalls }
        var requiresToolExecution: Bool  // true if firstToolCalls is non-nil and non-empty
    }
    ```
  - **ChatDelta Extensions**:
    ```swift
    extension ChatDelta {
        var firstContent: String? { choices.first?.delta.content }
        var firstFinishReason: String? { choices.first?.finishReason }
        var firstToolCallDeltas: [ToolCallDelta]? { choices.first?.delta.toolCalls }
    }
    ```
  - Purpose: Provides quick access to the most commonly used response data without navigating nested structures. `firstContent` returns the content from the first choice, `firstFinishReason` returns the finish reason, `totalTokens` returns the total token count (defaulting to 0 if unavailable). `requiresToolExecution` checks only `firstToolCalls` (not `firstFinishReason`) for provider compatibility. `firstToolCallDeltas` provides access to streaming tool call data.
  - **Token Usage Access Example**:
    ```swift
    let response = try await client.complete(request)

    // Access all token counts via the usage property
    if let usage = response.usage {
        print("Input tokens: \(usage.promptTokens)")
        print("Output tokens: \(usage.completionTokens)")
        print("Total tokens: \(usage.totalTokens)")
    }

    // Or use convenience property for quick total access
    print("Total: \(response.totalTokens)")  // Returns 0 if usage unavailable
    ```

### 5. Convenience Message Functions

Shorthand `@inlinable` free functions for creating common message types. These return `TextMessage` and work anywhere `TextMessage` works, including `@ChatBuilder` and `@SessionBuilder` blocks.

- `System(_ content: String) -> TextMessage` — creates `TextMessage(role: .system, content: content)`
- `UserMessage(_ content: String) -> TextMessage` — creates `TextMessage(role: .user, content: content)`, retained for compatibility
- `User(_ content: String) -> TextMessage` — creates `TextMessage(role: .user, content: content)`, preferred shorthand. Coexists with `UserID` config parameter because Swift resolves overloads by return type: in `@ChatBuilder` context (expecting `any ChatMessage`) only this function matches, while in `@ChatConfigBuilder` context (expecting `ChatConfigParameter`) only `UserID` matches.
- `Assistant(_ content: String) -> TextMessage` — creates `TextMessage(role: .assistant, content: content)`, useful for conversation history and few-shot examples

See [ToolSupportSpec.md](ToolSupportSpec.md) for usage examples.

### 6. Result Builders
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

- **ToolsBuilder**: Composes inline tool declarations for ChatRequest.
  - Signature:
    ```swift
    @resultBuilder
    struct ToolsBuilder {
        static func buildBlock(_ components: Tool...) -> [Tool]
        static func buildEither(first: [Tool]) -> [Tool]
        static func buildEither(second: [Tool]) -> [Tool]
        static func buildOptional(_ component: [Tool]?) -> [Tool]
        static func buildArray(_ components: [[Tool]]) -> [Tool]
    }
    ```
  - Purpose: Enables declarative inline tool declarations in `ChatRequest` initializers via a `tools:` parameter, supporting conditionals and loops.

- **SessionBuilder**: Composes mixed messages and tools for declarative ToolSession/Agent configuration.
  - Signature:
    ```swift
    @resultBuilder
    struct SessionBuilder {
        static func buildExpression(_ message: TextMessage) -> [SessionComponent]
        static func buildExpression(_ message: any ChatMessage) -> [SessionComponent]
        static func buildExpression(_ tool: AgentTool) -> [SessionComponent]
        static func buildBlock(_ components: [SessionComponent]...) -> [SessionComponent]
        static func buildEither(first: [SessionComponent]) -> [SessionComponent]
        static func buildEither(second: [SessionComponent]) -> [SessionComponent]
        static func buildOptional(_ component: [SessionComponent]?) -> [SessionComponent]
        static func buildArray(_ components: [[SessionComponent]]) -> [SessionComponent]
    }
    ```
  - Purpose: Enables Apple FoundationModels-style declarative configuration where both messages (e.g., `System("...")`) and tools (`AgentTool(...)`) can be mixed in a single builder block. Uses `SessionComponent` enum as the intermediate type.
  - Related type: `SessionComponent` enum with cases `.message(any ChatMessage)` and `.agentTool(AgentTool)`.

### 7. Actor: LLMClient
- Signature:
  ```swift
  actor LLMClient {
      init(baseURL: String, apiKey: String, sessionConfiguration: URLSessionConfiguration = .default) throws
      func complete(_ request: ChatRequest) async throws -> ChatResponse
      nonisolated func stream(_ request: ChatRequest) -> AsyncThrowingStream<ChatDelta, Error>
  }
  ```
- Purpose: Manages API calls with thread-safe state (e.g., `private let baseURL`, `private let apiKey`, `private let session: URLSession`).
- Initialization: Takes `baseURL` (complete endpoint), `apiKey`, and optional `sessionConfiguration` (defaults to `URLSessionConfiguration.default`). Throws `LLMError.missingBaseURL` if invalid/empty. Creates `URLSession` with the provided configuration.
- Methods:
  - `complete`: Sends non-streaming POST request to `baseURL`. Throws `LLMError` on failure (e.g., HTTP 429 for `rateLimit`).
  - `stream`: Returns `AsyncThrowingStream<ChatDelta, Error>` for streaming responses. `nonisolated` for usability without `await`.

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
   - Notes: Specifies complete `baseURL`, required `model`. Config block includes only desired parameters with control flow. Trailing commas supported (Swift 6.2+).

2. **Streaming** (OpenAI):
   ```swift
   let client = try LLMClient(baseURL: "https://api.openai.com/v1/chat/completions", apiKey: "sk-...")
   let stream = client.stream(
       try ChatRequest(model: "gpt-4o", stream: true) {
           Temperature(0.8)
           MaxTokens(200)
           UserID("user123")
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

For implementation details, see [SwiftChatCompletionsDSL-HOW.md](SwiftChatCompletionsDSL-HOW.md).

---

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

---

## Live Endpoint Tests (Opt-In)

An optional integration test suite (`LiveEndpointTests.swift`) validates the DSL against a real OpenAI-compatible server. All live tests are **skipped by default** and only run when explicitly enabled via environment variables.

### Configuration

| Environment Variable | Default | Description |
|---|---|---|
| `LIVE_TEST` | *(unset)* | Set to `1` to enable live tests |
| `LIVE_ENDPOINT_URL` | `http://127.0.0.1:1234` | Server endpoint URL |
| `LIVE_ENDPOINT_MODEL` | `nvidia/nemotron-3-nano` | Model identifier |
| `LIVE_ENDPOINT_API_KEY` | *(empty string)* | API key (local servers typically don't need one) |

### URL Path Handling
If the supplied URL has no path (or just `/`), `/v1/chat/completions` is appended automatically. URLs with an existing path are used as-is.

### Test Cases

The suite uses `@Suite(.serialized)` and Swift Testing's `.enabled(if:)` trait for opt-in gating:

1. **Basic Non-Streaming Completion** (`basicCompletion`): Sends a simple prompt via `client.complete()`, verifies response has non-empty content and at least one choice. Uses `RequestTimeout(120)` and `ResourceTimeout(180)` for slower local models.

2. **Streaming Completion** (`streamingCompletion`): Streams a response via `client.stream()`, verifies deltas arrive and content accumulates to a non-empty string.

3. **Tool Calling via ToolSession** (`toolCallingWithToolSession`): Defines a `get_current_time` tool with a `timezone` parameter, runs via `ToolSession`, verifies the model calls the tool and produces a final response incorporating the tool result.

4. **Agent Multi-Turn** (`agentMultiTurn`): Creates an `Agent` with a system prompt, sends two messages across turns, verifies non-empty responses and that conversation history grows to at least 4 messages.

### Running

```bash
# Run with defaults (local LM Studio on port 1234)
LIVE_TEST=1 swift test --filter LiveEndpointTests

# Run with custom endpoint
LIVE_TEST=1 LIVE_ENDPOINT_URL=http://other:8080 LIVE_ENDPOINT_MODEL=other-model swift test --filter LiveEndpointTests

# All simulated tests still pass without LIVE_TEST set
swift test
```

### Design Principles
- **No source changes required**: Lives in a separate test file with no modifications to existing code or tests.
- **No API key required by default**: Designed for local inference servers (e.g., LM Studio, Ollama).
- **Serialized execution**: Tests run sequentially to avoid overwhelming local servers.
- **Generous timeouts**: Non-streaming test uses extended timeouts for slower local models.

This spec provides a clear blueprint for an LLM code generator to produce a Swift 6.2+ package, ensuring a declarative, type-safe, and flexible DSL for OpenAI-compatible LLM servers.

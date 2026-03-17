# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Swift Package Manager project that implements `SwiftChatCompletionsDSL` - an embedded Swift DSL for communicating with LLM inference servers supporting OpenAI-compatible Chat Completions endpoints. The DSL provides a declarative, type-safe interface for both streaming and non-streaming chat completions, with full tool calling support and an agent abstraction for multi-turn conversations.

## Commands

### Building and Testing
- **Build**: `swift build`
- **Test**: `swift test`
- **Run tests with verbose output**: `swift test --verbose`

### Development
- **Clean build**: `swift package clean`
- **Generate Xcode project**: `swift package generate-xcodeproj`
- **Update dependencies**: `swift package update`

## Architecture

### Core Design Principles
- **Explicit Configuration**: Requires `baseURL` (complete endpoint URL) and `model` for every request
- **Result Builders**: Uses `@ChatConfigBuilder` for optional parameters, `@AgentToolBuilder` for agent tools, `@SessionBuilder` for mixed messages+tools in ChatRequest/ToolSession/Agent
- **Type Safety**: Enforces roles, parameters, and responses at compile time
- **Swift Concurrency**: Built with `async`/`await` and actors for thread-safe operations
- **Value Types**: Uses structs for performance and immutability
- **Macros Integration**: Core target depends on `SwiftChatCompletionsMacros`; `JSONSchema` and `Tool` are typealiases for macros types

### Key Components

1. **LLMClient (Actor)**: Thread-safe client for API communication
   - Manages HTTP requests to OpenAI-compatible endpoints
   - Supports both streaming and non-streaming responses
   - `stream()` is `nonisolated async throws` — setup errors surface at call site, not mid-iteration; cancellation cleans up via `continuation.onTermination`
   - Configurable request and resource timeouts for reliable network operations

2. **Result Builders**:
   - `@ChatBuilder`: Composes message sequences with control flow support
   - `@ChatConfigBuilder`: Composes configuration parameters declaratively
   - `@AgentToolBuilder`: Composes tool registrations for Agent
   - `@SessionBuilder`: Composes mixed messages and tools for declarative ToolSession/Agent init

3. **Protocol System**:
   - `ChatMessage`: Extensible protocol for different message types
   - `ChatConfigParameter`: Protocol for optional configuration parameters (requires `Sendable`)

4. **Configuration Structs**: Type-safe wrappers for API parameters with validation
   - `Temperature`, `MaxTokens`, `TopP`, `FrequencyPenalty`, `PresencePenalty`, `UserID`, etc.
   - `RequestTimeout`, `ResourceTimeout` for controlling HTTP timeouts
   - `ToolChoiceParam` for controlling tool selection behavior
   - Each validates input ranges and throws `LLMError.invalidValue(String)` on invalid values
   - `LogitBias`: throws if any bias value is outside `[-100, 100]`
   - `Stop`: throws if more than 4 sequences are provided
   - `N`: throws if value exceeds 128

5. **Conversation Management**:
   - `ChatConversation`: Utility for managing persistent conversation history
   - Supports both builder pattern and array-based message initialization
   - Convenience methods: `addUser()`, `addAssistant()`, `addSystem()`, `addAssistantToolCalls()`, `addToolResult()`, `clear()`
   - Utility properties: `lastMessageRole`, `messageCount`

6. **Tool Calling Types**:
   - `JSONSchema`: Type-safe JSON Schema representation (indirect enum, cases: `object`, `array`, `string`, `integer`, `number`, `boolean`, `null`)
   - `ToolCall` / `ToolCallDelta`: Parsed tool calls from non-streaming / streaming responses (with public inits)
   - `ToolCall.decodeArguments()`: Generic helper to decode raw JSON arguments into typed Swift values
   - `ToolCallAccumulator`: Accumulates streaming `ToolCallDelta` chunks into complete `ToolCall` objects
   - `ToolChoice`: Controls model tool selection (`auto`, `none`, `required`, `function(name)`)
   - `AssistantToolCallMessage`: Message type for assistant tool call requests
   - `ToolResultMessage`: Message type for tool execution results
   - `AssistantToolCall(_ toolCalls:)` / `ToolResult(id:content:)`: convenience constructors (lowercase-style, like `System()`, `User()`)

7. **ToolSession (Struct)**: Orchestrates the tool-calling loop
   - Sends request → parses tool_calls → executes handlers in parallel → sends results → repeats
   - Uses `withThrowingTaskGroup` for parallel tool execution
   - Returns `ToolSessionResult` with response, messages, iterations, log, and `hitIterationLimit: Bool`
   - When `maxIterations` is reached, returns result with `hitIterationLimit: true` instead of throwing; use `failOnIterationLimit: Bool = false` param to opt into throwing behavior
   - Tool handler errors are caught and sent back to the model as a `ToolResultMessage` (error string), not thrown; only `unknownTool` propagates as an error
   - All inits `throws` on duplicate tool names (not `precondition`)
   - Declarative init with `@SessionBuilder` for mixed messages+tools, plus `run(_ prompt:)` shorthand; declarative init accepts `@ChatConfigBuilder config:` parameter
   - `SessionComponent` enum and `SessionBuilder` result builder for declarative configuration
   - `SessionBuilder` accepts bare `Tool` definitions (`.toolDefinition`) as well as `AgentTool` and messages

8. **Agent (Actor)**: High-level persistent agent
   - Manages `ChatConversation` for history across multiple `send()` calls
   - Uses `ToolSession` internally for automatic tool-calling loops
   - Maintains `[TranscriptEntry]` for debugging/observability
   - All inits `throws` on duplicate tool names (not `precondition`)
   - Builder init with `@AgentToolBuilder` for declarative tool registration
   - Declarative init with `@SessionBuilder` for mixed messages+tools
   - Primary method is `send(_:)`; no `run(_:)` alias
   - Introspection: `registeredToolNames`, `toolCount` computed properties

9. **Response Convenience Extensions**:
   - `ChatResponse`: `firstContent: String?`, `firstFinishReason`, `totalTokens: Int?`, `firstToolCalls`, `requiresToolExecution`
   - `ChatResponse.Message.content` is `String?` (null from API decodes as `nil`); use `.contentOrEmpty` for `String`
   - `totalTokens` returns `nil` when `usage` is absent in the response
   - `ChatDelta`: `firstContent`, `firstFinishReason`, `firstToolCallDeltas`

10. **Type Aliases**:
    - `ChatMessages`: Alias for `[any ChatMessage]` for cleaner type signatures

### JSON Serialization
- Uses `CodingKeys` to map Swift camelCase to OpenAI snake_case format
- Example: `maxTokens` → `max_tokens`, `topP` → `top_p`, `toolCalls` → `tool_calls`
- `ChatResponse.Message.content` is `String?`; null from API decodes as `nil`

### Error Handling
Custom `LLMError` enum covers:
- Invalid URLs, encoding/decoding failures
- Network errors, server errors with status codes
- Rate limiting (HTTP 429)
- Missing required fields (`baseURL`, `model`)
- Invalid parameter values with descriptive messages (`invalidValue(String)`)
- Tool calling errors: `maxIterationsExceeded(Int)`, `unknownTool(String)`, `toolExecutionFailed(toolName:message:)`
- Network-specific: `requestTimeout`, `resourceTimeout`, `connectionFailed(String)`
- `isRetryable: Bool` computed property — `true` for `rateLimit`, `requestTimeout`, `resourceTimeout`, `connectionFailed`, and `serverError` with status ≥ 500

### Swift Version Requirements
- **Minimum**: Swift 6.2+ (for trailing commas, `nonisolated`, improved type inference)
- **Testing Framework**: Swift Testing with `#expect` syntax
- **Platforms**: macOS 13.0+, iOS 16.0+

## Package Structure

### Products
- **SwiftChatCompletionsDSL**: Core library (depends on SwiftChatCompletionsMacros)

### Targets
- **SwiftChatCompletionsDSL**: Core target (depends on SwiftChatCompletionsMacros)
- **SwiftChatCompletionsDSLTests**: Tests for core target

## Implementation Details

### URL Handling
- `baseURL` is treated as the complete endpoint URL (no path appending)
- Examples: `https://api.openai.com/v1/chat/completions`, `https://custom-server.com/chat`

### Timeout Configuration
- **RequestTimeout**: Controls individual HTTP request timeouts (10-900 seconds)
- **ResourceTimeout**: Controls complete resource loading timeouts (30-3600 seconds)
- Timeouts are applied to both streaming and non-streaming requests
- Custom URLSession configurations are created when timeouts are specified

### Streaming Support
- Parses Server-Sent Events (SSE) format
- Handles `data: [DONE]` termination signals
- `stream()` is `nonisolated async throws -> AsyncThrowingStream<ChatDelta, Error>` — setup errors (invalid URL, encoding) throw at call site; `continuation.onTermination` cancels the inner `Task` if the caller breaks early

### Tool Calling
- `Tool` is a typealias for `ToolDefinition` from `SwiftChatCompletionsMacros`; use `Tool(name:description:parameters:)` directly
- `JSONSchema` is a typealias for `JSONSchemaValue` from `SwiftChatCompletionsMacros`; dict convenience `object(properties:[String:JSONSchemaValue], required:)` adds dictionary syntax
- `ToolSession.ToolHandler` signature: `@Sendable (String) async throws -> String`
- Parallel tool execution via `withThrowingTaskGroup` when API returns multiple tool_calls
- `Agent` uses `ToolSession` internally for automatic tool-calling loops
- `ToolCall.decodeArguments()` provides typed argument decoding, wrapping errors as `LLMError.decodingFailed`
- `ToolCallAccumulator` assembles streaming `ToolCallDelta` chunks into complete `ToolCall` objects
- Duplicate tool name detection: `throws LLMError.invalidValue` in all `ToolSession`/`Agent` inits (both explicit and builder)
- Tool handler errors are caught inside `withThrowingTaskGroup` and returned as error strings to the model (not re-thrown); only `unknownTool` escapes as an error
- `ToolSessionResult.hitIterationLimit: Bool` indicates whether session ended at iteration limit
- `requiresToolExecution` checks only `firstToolCalls` (not `firstFinishReason`) for provider compatibility

### Macros Integration
- `JSONSchema = JSONSchemaValue` (typealias) — no runtime conversion needed
- `Tool = ToolDefinition` (typealias) — no runtime conversion needed
- `AgentTool.init<T: ChatCompletionsTool>(_ instance: T)` wraps macro-defined tools for Agent use (defined in `Agent.swift`)

### Extensibility
- Add custom message types by conforming to `ChatMessage`
- Add custom parameters by conforming to `ChatConfigParameter`
- Support for multimodal content (images, etc.)

## Testing Strategy

The test suite uses Swift Testing framework and covers:
- Parameter validation and error cases (including LogitBias range, Stop max-4, N max-128)
- Result builder functionality
- Conversation history management
- Async streaming operations (with mocked `URLSession`)
- JSON serialization/deserialization
- Edge cases (empty messages, rate limits)
- JSONSchema encoding for all 7 cases (including `null`)
- ToolCall/ToolCallDelta decoding and public inits
- ToolCall.decodeArguments() success and error paths
- ToolCallAccumulator (basic, parallel, reset)
- ToolChoice encoding for all 4 variants
- AssistantToolCallMessage/ToolResultMessage encoding
- AssistantToolCall() and ToolResult() convenience functions
- ChatResponse/ChatDelta with tool calls
- ChatResponse.Message.content as String? (null → nil, empty → "")
- totalTokens as Int? (nil when usage absent)
- LLMError.isRetryable (true for rateLimit, requestTimeout, resourceTimeout, connectionFailed, 5xx; false for client errors)
- ToolSession integration tests (single, parallel, hitIterationLimit flag, unknown tool, handler-error-to-model)
- ToolSession/Agent duplicate detection throws (all inits)
- Agent multi-turn conversation, transcript logging, reset, send without tools
- Agent builder duplicate tool detection, no-tools creation
- Agent tool introspection (registeredToolNames, toolCount)
- Assistant() and other convenience message functions
- User() convenience function and UserID config parameter coexistence
- SessionBuilder with messages and tools
- ChatRequest @SessionBuilder configure: init with messages+tools
- ToolSession declarative init and run(_ prompt:) shorthand

## File Structure
```
Sources/SwiftChatCompletionsDSL/
├── SwiftChatCompletionsDSL.swift           # Core types, messages, ChatRequest, LLMClient
├── ToolSession.swift                        # ToolSession, ToolSessionResult, ToolCallLogEntry
├── Agent.swift                              # Agent actor, AgentTool, AgentToolBuilder, TranscriptEntry
├── SwiftChatCompletionsDSL.docc/           # DocC documentation catalog
│   ├── SwiftChatCompletionsDSL.md          # Main documentation
│   ├── Architecture.md                      # Technical architecture
│   ├── DSL.md                               # DSL guide for beginners
│   └── Usage.md                             # Usage examples
Tests/SwiftChatCompletionsDSLTests/
├── SwiftChatCompletionsDSLTests.swift      # All test cases (130 tests)
Spec/
├── SwiftChatCompletionsDSL.md              # Core public API specification
├── SwiftChatCompletionsDSL-HOW.md          # Core implementation details
├── ToolCalling.md                           # Tool calling public API specification
├── ToolCalling-HOW.md                       # Tool calling implementation details
├── ToolSupportSpec.md                       # Tool support public API specification
├── ToolSupportSpec-HOW.md                   # Tool support implementation details
├── DocumentationSpec.md                     # Documentation requirements
Examples/
├── BasicUsage.swift                         # Usage examples
.claude/skills/
├── using-swift-chat-completions-macros/     # Macro usage skill for AI assistants
│   └── SKILL.md
```

The project follows Swift Package Manager conventions with core types in the main source file and tool orchestration (ToolSession, Agent) in separate files. The core target depends directly on `SwiftChatCompletionsMacros`, with `JSONSchema` and `Tool` as typealiases for macros types.

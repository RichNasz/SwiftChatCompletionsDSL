# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Swift Package Manager project that implements `SwiftChatCompletionsDSL` - an embedded Swift DSL for communicating with LLM inference servers supporting OpenAI-compatible Chat Completions endpoints. The DSL provides a declarative, type-safe interface for both streaming and non-streaming chat completions, with full tool calling support and an agent abstraction for multi-turn conversations.

## Commands

### Building and Testing
- **Build**: `swift build`
- **Test**: `swift test`
- **Run tests with verbose output**: `swift test --verbose`
- **Run live endpoint tests** (two-phase): `./scripts/test-live.sh` — runs all simulated tests first, then live tests only if simulated tests pass. Forwards `LIVE_ENDPOINT_URL`, `LIVE_ENDPOINT_MODEL`, `LIVE_ENDPOINT_API_KEY` env vars.

### Development
- **Clean build**: `swift package clean`
- **Generate Xcode project**: `swift package generate-xcodeproj`
- **Update dependencies**: `swift package update`

## Architecture

### Core Design Principles
- **Explicit Configuration**: Requires `baseURL` (complete endpoint URL) and `model` for every request
- **Result Builders**: Uses `@ChatBuilder` for messages, `@ChatConfigBuilder` for optional parameters, `@AgentToolBuilder` for agent tools, `@SessionBuilder` for mixed messages+tools
- **Type Safety**: Enforces roles, parameters, and responses at compile time
- **Swift Concurrency**: Built with `async`/`await` and actors for thread-safe operations
- **Value Types**: Uses structs for performance and immutability
- **Macros Integration**: Core target depends on `SwiftLLMToolMacros`; `JSONSchema` and `Tool` are typealiases for macros types

### Key Components

1. **LLMClient (Actor)**: Thread-safe client for API communication
   - Manages HTTP requests to OpenAI-compatible endpoints
   - Supports both streaming and non-streaming responses
   - Uses `nonisolated` streaming method for better usability
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

5. **Conversation Management**:
   - `ChatConversation`: Utility for managing persistent conversation history
   - Supports both builder pattern and array-based message initialization
   - Convenience methods: `addUser()`, `addAssistant()`, `addSystem()`, `addAssistantToolCalls()`, `addToolResult()`, `clear()`
   - Utility properties: `lastMessageRole`, `messageCount`

6. **Tool Calling Types**:
   - `JSONSchema`: Type-safe JSON Schema representation (indirect enum, cases: `object`, `array`, `string`, `integer`, `number`, `boolean`, `null`)
   - `ExtraContent`: Provider-specific extra content (e.g. Gemini `thought_signature` at `extra_content.google.thought_signature`); nested `GoogleContent` struct with `CodingKeys`
   - `ToolCall` / `ToolCallDelta`: Parsed tool calls from non-streaming / streaming responses (with public inits); include optional `extraContent: ExtraContent?` (mapped to `extra_content` via CodingKeys)
   - `ToolCall.FunctionCall` / `ToolCallDelta.FunctionCallDelta`: `name` + `arguments` only (no provider-specific fields)
   - `ToolCall.decodeArguments()`: Generic helper to decode raw JSON arguments into typed Swift values
   - `ToolCallAccumulator`: Accumulates streaming `ToolCallDelta` chunks into complete `ToolCall` objects; preserves `extraContent` through accumulation
   - `ToolChoice`: Controls model tool selection (`auto`, `none`, `required`, `function(name)`)
   - `AssistantToolCallMessage`: Message type for assistant tool call requests
   - `ToolResultMessage`: Message type for tool execution results

7. **ToolSession (Struct)**: Orchestrates the tool-calling loop
   - Sends request → parses tool_calls → executes handlers in parallel → sends results → repeats
   - Uses `withThrowingTaskGroup` for parallel tool execution
   - Returns `ToolSessionResult` with response, messages, iterations, and execution log
   - Configurable `maxIterations` to prevent infinite loops
   - Duplicate tool name detection via `precondition`
   - Error context includes error type name in `toolExecutionFailed`
   - Declarative init with `@SessionBuilder` for mixed messages+tools, plus `run(_ prompt:)` shorthand
   - `SessionComponent` enum and `SessionBuilder` result builder for declarative configuration
   - `stream()` methods return `AsyncThrowingStream<ToolSessionEvent, Error>` with true SSE token-level streaming
   - `ToolSessionEvent` enum: `.textDelta`, `.modelResponse`, `.toolStarted`, `.toolCompleted`, `.completed`
   - `stream()` uses `client.stream()` (SSE) internally; yields `.textDelta(String)` for each token as it arrives
   - Synthesizes a `ChatResponse` from accumulated streaming data for the `.completed` result

8. **Agent (Actor)**: High-level persistent agent
   - Manages `ChatConversation` for history across multiple `send()` calls
   - Uses `ToolSession` internally for automatic tool-calling loops
   - Maintains `[TranscriptEntry]` for debugging/observability
   - Builder init with `@AgentToolBuilder` for declarative tool registration (throws on duplicate tool names)
   - Declarative init with `@SessionBuilder` for mixed messages+tools
   - `run(_:)` method as alias for `send(_:)`
   - `streamSend(_:)` / `streamRun(_:)` return `AsyncThrowingStream<ToolSessionEvent, Error>` for progressive updates
   - Introspection: `registeredToolNames`, `toolCount` computed properties

9. **Response Convenience Extensions**:
   - `ChatResponse`: `firstContent`, `firstFinishReason`, `totalTokens`, `firstToolCalls`, `requiresToolExecution`
   - `ChatDelta`: `firstContent`, `firstFinishReason`, `firstToolCallDeltas`

10. **Type Aliases**:
    - `ChatMessages`: Alias for `[any ChatMessage]` for cleaner type signatures

### JSON Serialization
- Uses `CodingKeys` to map Swift camelCase to OpenAI snake_case format
- Example: `maxTokens` → `max_tokens`, `topP` → `top_p`, `toolCalls` → `tool_calls`, `extraContent` → `extra_content`
- `ChatResponse.Message.content` decodes `null` as `""` for source compatibility

### Error Handling
Custom `LLMError` enum covers:
- Invalid URLs, encoding/decoding failures
- Network errors, server errors with status codes
- Rate limiting (HTTP 429)
- Missing required fields (`baseURL`, `model`)
- Invalid parameter values with descriptive messages (`invalidValue(String)`)
- Tool calling errors: `maxIterationsExceeded(Int)`, `unknownTool(String)`, `toolExecutionFailed(toolName:message:)`

### Swift Version Requirements
- **Minimum**: Swift 6.2+ (for trailing commas, `nonisolated`, improved type inference)
- **Testing Framework**: Swift Testing with `#expect` syntax
- **Platforms**: macOS 13.0+, iOS 16.0+

## Package Structure

### Products
- **SwiftChatCompletionsDSL**: Core library (depends on SwiftLLMToolMacros)

### Targets
- **SwiftChatCompletionsDSL**: Core target (depends on SwiftLLMToolMacros)
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
- Returns `AsyncThrowingStream<ChatDelta, Error>` for real-time content streaming

### Tool Calling
- `Tool` is a typealias for `ToolDefinition` from `SwiftLLMToolMacros`; use `Tool(name:description:parameters:)` directly
- `JSONSchema` is a typealias for `JSONSchemaValue` from `SwiftLLMToolMacros`; dict convenience `object(properties:[String:JSONSchemaValue], required:)` adds dictionary syntax
- `ToolSession.ToolHandler` signature: `@Sendable (String) async throws -> String`
- Parallel tool execution via `withThrowingTaskGroup` when API returns multiple tool_calls
- `Agent` uses `ToolSession` internally for automatic tool-calling loops
- `ToolCall.decodeArguments()` provides typed argument decoding, wrapping errors as `LLMError.decodingFailed`
- `ToolCallAccumulator` assembles streaming `ToolCallDelta` chunks into complete `ToolCall` objects
- Gemini thinking model support: `ExtraContent` struct models `extra_content.google.thought_signature`; stored on `ToolCall.extraContent` and `ToolCallDelta.extraContent` (not inside `FunctionCall`). Optional with `nil` default; flows through accumulation and Codable round-trips automatically.
- Duplicate tool name detection: `precondition` in `ToolSession`/`Agent` explicit init, `throws` in `Agent` builder init
- `requiresToolExecution` checks only `firstToolCalls` (not `firstFinishReason`) for provider compatibility

### Macros Integration
- `JSONSchema = JSONSchemaValue` (typealias) — no runtime conversion needed
- `Tool = ToolDefinition` (typealias) — no runtime conversion needed
- `AgentTool.init<T: LLMTool>(_ instance: T)` wraps macro-defined tools for Agent use (defined in `Agent.swift`)

### Extensibility
- Add custom message types by conforming to `ChatMessage`
- Add custom parameters by conforming to `ChatConfigParameter`
- Support for multimodal content (images, etc.)

## Testing Strategy

The test suite uses Swift Testing framework and covers:
- Parameter validation and error cases
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
- ChatResponse/ChatDelta with tool calls
- ToolSession integration tests (single, parallel, max iterations, max iterations boundary, unknown tool, handler throws)
- Agent multi-turn conversation, transcript logging, reset, send without tools
- Agent builder duplicate tool detection, no-tools creation
- Agent tool introspection (registeredToolNames, toolCount)
- Assistant() and other convenience message functions
- User() convenience function and UserID config parameter coexistence
- SessionBuilder with messages and tools
- ToolSession declarative init and run(_ prompt:) shorthand
- ToolSession stream with SSE token-level streaming (basic with textDelta, no tools needed, multiple iterations, error propagation, max iterations, declarative shorthand)
- Agent declarative init with @SessionBuilder and run(_:) alias
- Agent streamSend (basic with tools, no tools, streamRun alias)
- **Live endpoint tests** (opt-in via `LIVE_TEST=1` env var, skipped by default):
  - Basic non-streaming completion, streaming completion, tool calling via ToolSession, Agent multi-turn
  - Configurable via `LIVE_ENDPOINT_URL`, `LIVE_ENDPOINT_MODEL`, `LIVE_ENDPOINT_API_KEY` env vars
  - Auto-appends `/v1/chat/completions` if URL has no path
  - Run with: `./scripts/test-live.sh` (two-phase: simulated first, then live)
  - Or directly: `LIVE_TEST=1 swift test --filter LiveEndpointTests`

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
├── SwiftChatCompletionsDSLTests.swift      # All test cases (140 simulated tests)
├── LiveEndpointTests.swift                 # Opt-in live endpoint integration tests (4 tests, requires LIVE_TEST=1)
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
scripts/
├── test-live.sh                             # Two-phase test runner: simulated tests then live tests
.claude/skills/
├── using-swift-llm-tool-macros/     # Macro usage skill for AI assistants
│   └── SKILL.md
```

The project follows Swift Package Manager conventions with core types in the main source file and tool orchestration (ToolSession, Agent) in separate files. The core target depends directly on `SwiftLLMToolMacros`, with `JSONSchema` and `Tool` as typealiases for macros types.

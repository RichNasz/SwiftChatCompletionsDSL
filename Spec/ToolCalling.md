# Tool Calling & Agent Capability Specification

## Overview

This specification defines the tool calling and agent orchestration types for SwiftChatCompletionsDSL. These additions enable the DSL to parse tool_calls from API responses, manage the tool-calling loop, and provide a high-level agent abstraction for persistent conversations with tool use.

### JSONSchema (indirect enum)
Type-safe JSON Schema representation replacing `[String: String]` for tool parameters.

- **Cases**: `object`, `array`, `string`, `integer`, `number`, `boolean`, `null`
- **Conformance**: `Sendable`, `Equatable`, `Encodable`
- **Encoding**: Produces standard JSON Schema format (`{"type":"object","properties":{...},"required":[...]}`)
- **Object type**: Includes `additionalProperties: false` per OpenAI requirements

### ToolCall (struct)
Parsed tool call from a non-streaming API response.

- **Fields**: `id: String`, `type: String`, `function: FunctionCall`, `extraContent: ExtraContent?`
- **FunctionCall**: `name: String`, `arguments: String` (raw JSON)
- **CodingKeys**: `extra_content` maps to `extraContent`
- **Public inits**: Both `ToolCall` and `FunctionCall` have explicit public initializers. `ToolCall.init` has `type: String = "function"` and `extraContent: ExtraContent? = nil` defaults.
- **Conformance**: `Codable`, `Sendable`
- **decodeArguments()**: Generic helper to decode raw JSON arguments into typed Swift values:
  ```swift
  public func decodeArguments<T: Decodable>(_ type: T.Type = T.self) throws -> T
  ```
  Handles UTF-8 conversion safely and wraps errors as `LLMError.decodingFailed`

### ToolCallDelta (struct)
Incremental tool call from a streaming delta.

- **Fields**: `index: Int`, `id: String?`, `type: String?`, `function: FunctionCallDelta?`, `extraContent: ExtraContent?`
- **FunctionCallDelta**: `name: String?`, `arguments: String?`
- **CodingKeys**: `extra_content` maps to `extraContent`
- **Public inits**: Both `ToolCallDelta` and `FunctionCallDelta` have explicit public initializers. `ToolCallDelta.init` has `extraContent: ExtraContent? = nil` default.
- **Conformance**: `Codable`, `Sendable`

### ToolCallAccumulator (struct)
Accumulates streaming `ToolCallDelta` chunks into complete `ToolCall` objects.

- **Methods**: `append(_:)` to add deltas, `reset()` to clear state
- **Properties**: `toolCalls: [ToolCall]` returns accumulated complete tool calls ordered by index
- **Conformance**: `Sendable`
- **Purpose**: Eliminates boilerplate of manually tracking and concatenating partial id, name, and argument fragments during streaming
- **Gemini support**: Preserves `extraContent` from deltas and passes it through to assembled `ToolCall` objects

### ToolChoice (enum)
Controls model tool selection behavior.

- **Cases**: `auto`, `none`, `required`, `function(String)`
- **Conformance**: `Sendable`, `Encodable`
- **Encoding**: String cases encode as string literals, `.function(name)` encodes as `{"type":"function","function":{"name":"..."}}`

### ToolChoiceParam (struct)
`ChatConfigParameter` wrapper for `ToolChoice`.

- Applies `ToolChoice` to `ChatRequest.toolChoice`

### AssistantToolCallMessage (struct)
`ChatMessage` for assistant messages containing tool_calls.

- **Fields**: `role: Role = .assistant`, `content: String?`, `toolCalls: [ToolCall]`
- **JSON keys**: `tool_calls` for snake_case serialization

### ToolResultMessage (struct)
`ChatMessage` for tool results sent back to the model.

- **Fields**: `role: Role = .tool`, `toolCallId: String`, `content: String`
- **JSON keys**: `tool_call_id` for snake_case serialization

### SessionComponent (enum)
A component that can appear inside a `@SessionBuilder` block. Allows mixing messages and tools in a single builder.

- **Cases**: `.message(any ChatMessage)`, `.agentTool(AgentTool)`
- **Conformance**: `Sendable`

### SessionBuilder (result builder)
Declarative syntax for configuring sessions with both messages and tools.

- **buildExpression**: Accepts `TextMessage`, `any ChatMessage`, or `AgentTool`
- **Control flow**: `buildEither`, `buildOptional`, `buildArray` for conditionals and loops

### ToolSession (struct)
Orchestrates the tool-calling loop: send → parse tool_calls → execute handlers → send results → repeat.

- **ToolHandler**: `@Sendable (String) async throws -> String`
- **Explicit init**: `client: LLMClient`, `tools: [Tool]`, `toolChoice: ToolChoice? = nil`, `maxIterations: Int = 10`, `handlers: [String: ToolHandler]`
- **Declarative init**: `client: LLMClient`, `model: String`, `toolChoice: ToolChoice? = nil`, `maxIterations: Int = 10`, `@SessionBuilder configure: () -> [SessionComponent]`
- **Duplicate detection**: Both inits use `precondition` (crashes on duplicate tool names)
- **run(model:messages:config:)**: Accepts model, messages, `@ChatConfigBuilder` config block; returns `ToolSessionResult`
- **run(model:messages:configParams:)**: Accepts model, messages, `[ChatConfigParameter]` directly (not a builder); returns `ToolSessionResult`. This overload is what `Agent.send()` calls internally.
- **run(_ prompt:)**: Shorthand for declarative init — appends user message to initial messages and runs with stored model; returns `ToolSessionResult`. Precondition failure if called on explicit init (no model stored).
- **Error**: Handler errors are wrapped as `LLMError.toolExecutionFailed(toolName:message:)`

### ToolSessionResult (struct)
Result of a ToolSession run.

- **Fields**: `response: ChatResponse`, `messages: [any ChatMessage]`, `iterations: Int`, `log: [ToolCallLogEntry]`

### ToolCallLogEntry (struct)
Log entry for a single tool call execution.

- **Fields**: `name: String`, `arguments: String`, `result: String`, `duration: Duration`

### Agent (actor)
High-level persistent agent with conversation history, parallel tool execution, and transcript.

- **Explicit init**: `client: LLMClient`, `model: String`, `systemPrompt: String? = nil`, `tools: [Tool] = []`, `toolChoice: ToolChoice? = nil`, `toolHandlers: [String: ToolSession.ToolHandler] = [:]`, `config: [ChatConfigParameter] = []`, `maxToolIterations: Int = 10`
  - Uses `precondition` for duplicate tool name detection (crashes)
- **Builder init**: `client: LLMClient`, `model: String`, `systemPrompt: String? = nil`, `maxToolIterations: Int = 10`, `@ChatConfigBuilder config:`, `@AgentToolBuilder tools:`
  - `toolChoice` is always `nil` in this init
  - Throws `LLMError.invalidValue` on duplicate tool names
- **Declarative init**: `client: LLMClient`, `model: String`, `maxToolIterations: Int = 10`, `@SessionBuilder configure:`
  - `toolChoice` is always `nil`, `configParams` = empty
  - Throws `LLMError.invalidValue` on duplicate tool names
- **Methods**: `send(_:) -> String`, `run(_:) -> String` (alias for `send`), `reset()`
- **Properties**: `history: [any ChatMessage]`, `transcript: [TranscriptEntry]`, `registeredToolNames: [String]`, `toolCount: Int`

### TranscriptEntry (enum)
Structured log entries for Agent debugging.

- **Cases**: `userMessage(String)`, `assistantMessage(String)`, `toolCall(name:arguments:)`, `toolResult(name:result:duration:)`, `error(String)`

### AgentTool (struct)
Pairs a `Tool` definition with its handler closure.

- **Fields**: `tool: Tool`, `handler: ToolSession.ToolHandler`

### AgentToolBuilder (result builder)
Declarative syntax for registering tools with Agent.

For implementation details, see [ToolCalling-HOW.md](ToolCalling-HOW.md).

---

## Modified Types

The table below documents what was added to existing types for tool calling support. Complete type definitions (including these tool fields) now live in [SwiftChatCompletionsDSL.md](SwiftChatCompletionsDSL.md). This table is retained as a change log for understanding what was added and why.

| Type | Change |
|------|--------|
| `Tool.Function.parameters` | `[String: String]` → `JSONSchema` (deprecated compat init kept) |
| `ChatRequest` | Add `toolChoice: ToolChoice?` field + encoding |
| `ChatResponse.Message` | Add `toolCalls: [ToolCall]?`, custom decoder for null content → `""` |
| `ChatDelta.Delta` | Add `toolCalls: [ToolCallDelta]?` |
| `LLMError` | Add `maxIterationsExceeded(Int)`, `unknownTool(String)`, `toolExecutionFailed(toolName:message:)` |
| `ChatConversation` | Add `addAssistantToolCalls()`, `addToolResult()` |
| `ChatResponse` | Add `firstToolCalls`, `requiresToolExecution` (checks `firstToolCalls` only, not `firstFinishReason`) |
| `ChatDelta` | Add `firstToolCallDeltas` |

## Backward Compatibility

- `Tool.Function` deprecated init with `[String: String]` preserved
- `ChatResponse.Message.content` stays `String` type; null decodes as `""`
- All new fields are optional/additive
- New `LLMError` cases work with existing `default` switches
- `User` config struct renamed to `UserID`
- `User()` convenience function added for creating user messages (replaces `UserMessage()` as preferred shorthand)
- All existing inits for `ToolSession` and `Agent` remain unchanged; new declarative inits are additive
- `Agent.run(_:)` is an additive alias for `send(_:)`

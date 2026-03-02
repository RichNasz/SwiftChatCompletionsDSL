# Tool Calling & Agent Capability Specification

## Overview

This specification defines the tool calling and agent orchestration types for SwiftChatCompletionsDSL. These additions enable the DSL to parse tool_calls from API responses, manage the tool-calling loop, and provide a high-level agent abstraction for persistent conversations with tool use.

## New Types

### JSONSchema (indirect enum)
Type-safe JSON Schema representation replacing `[String: String]` for tool parameters.

- **Cases**: `object`, `array`, `string`, `integer`, `number`, `boolean`, `null`
- **Conformance**: `Sendable`, `Equatable`, `Encodable`
- **Encoding**: Produces standard JSON Schema format (`{"type":"object","properties":{...},"required":[...]}`)
- **Object type**: Includes `additionalProperties: false` per OpenAI requirements

### ToolCall (struct)
Parsed tool call from a non-streaming API response.

- **Fields**: `id: String`, `type: String`, `function: FunctionCall`
- **FunctionCall**: `name: String`, `arguments: String` (raw JSON)
- **Public inits**: Both `ToolCall` and `FunctionCall` have explicit public initializers
- **Conformance**: `Codable`, `Sendable`
- **decodeArguments()**: Generic helper to decode raw JSON arguments into typed Swift values:
  ```swift
  public func decodeArguments<T: Decodable>(_ type: T.Type = T.self) throws -> T
  ```
  Handles UTF-8 conversion safely and wraps errors as `LLMError.decodingFailed`

### ToolCallDelta (struct)
Incremental tool call from a streaming delta.

- **Fields**: `index: Int`, `id: String?`, `type: String?`, `function: FunctionCallDelta?`
- **FunctionCallDelta**: `name: String?`, `arguments: String?`
- **Public inits**: Both `ToolCallDelta` and `FunctionCallDelta` have explicit public initializers
- **Conformance**: `Codable`, `Sendable`

### ToolCallAccumulator (struct)
Accumulates streaming `ToolCallDelta` chunks into complete `ToolCall` objects.

- **Methods**: `append(_:)` to add deltas, `reset()` to clear state
- **Properties**: `toolCalls: [ToolCall]` returns accumulated complete tool calls ordered by index
- **Conformance**: `Sendable`
- **Purpose**: Eliminates boilerplate of manually tracking and concatenating partial id, name, and argument fragments during streaming

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

### ToolSession (struct)
Orchestrates the tool-calling loop: send → parse tool_calls → execute handlers → send results → repeat.

- **ToolHandler**: `@Sendable (String) async throws -> String`
- **Init parameters**: `client`, `tools`, `toolChoice`, `maxIterations`, `handlers`
- **Duplicate detection**: `precondition` fails if two tools share the same name
- **run()**: Accepts model, messages, config; returns `ToolSessionResult`
- **Loop logic**: Parallel tool execution via `withThrowingTaskGroup`
- **Error context**: `toolExecutionFailed` message includes error type name: `"[\(type(of: error))] \(error.localizedDescription)"`

### ToolSessionResult (struct)
Result of a ToolSession run.

- **Fields**: `response: ChatResponse`, `messages: [any ChatMessage]`, `iterations: Int`, `log: [ToolCallLogEntry]`

### ToolCallLogEntry (struct)
Log entry for a single tool call execution.

- **Fields**: `name: String`, `arguments: String`, `result: String`, `duration: Duration`

### Agent (actor)
High-level persistent agent with conversation history, parallel tool execution, and transcript.

- **Init**: client, model, systemPrompt, tools, toolChoice, toolHandlers, config, maxToolIterations
  - Explicit init: `precondition` fails on duplicate tool names
- **Builder init**: Uses `@AgentToolBuilder` for declarative tool registration
  - Throws `LLMError.invalidValue("Duplicate tool name: '\(name)'")`  on duplicate tool names
- **Methods**: `send(_:)`, `reset()`
- **Properties**: `history`, `transcript`, `registeredToolNames: [String]`, `toolCount: Int`
- Uses `ToolSession` internally

### TranscriptEntry (enum)
Structured log entries for Agent debugging.

- **Cases**: `userMessage(String)`, `assistantMessage(String)`, `toolCall(name:arguments:)`, `toolResult(name:result:duration:)`, `error(String)`

### AgentTool (struct)
Pairs a `Tool` definition with its handler closure.

- **Fields**: `tool: Tool`, `handler: ToolSession.ToolHandler`

### AgentToolBuilder (result builder)
Declarative syntax for registering tools with Agent.

## Modified Types

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

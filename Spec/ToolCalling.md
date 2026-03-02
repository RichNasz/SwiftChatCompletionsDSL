# Tool Calling & Agent Capability Specification

## Overview

This specification defines the tool calling and agent orchestration types for SwiftChatCompletionsDSL. These additions enable the DSL to parse tool_calls from API responses, manage the tool-calling loop, and provide a high-level agent abstraction for persistent conversations with tool use.

## New Types

### JSONSchema (indirect enum)
Type-safe JSON Schema representation replacing `[String: String]` for tool parameters.

- **Cases**: `object`, `array`, `string`, `integer`, `number`, `boolean`
- **Conformance**: `Sendable`, `Equatable`, `Encodable`
- **Encoding**: Produces standard JSON Schema format (`{"type":"object","properties":{...},"required":[...]}`)
- **Object type**: Includes `additionalProperties: false` per OpenAI requirements

### ToolCall (struct)
Parsed tool call from a non-streaming API response.

- **Fields**: `id: String`, `type: String`, `function: FunctionCall`
- **FunctionCall**: `name: String`, `arguments: String` (raw JSON)
- **Conformance**: `Codable`, `Sendable`

### ToolCallDelta (struct)
Incremental tool call from a streaming delta.

- **Fields**: `index: Int`, `id: String?`, `type: String?`, `function: FunctionCallDelta?`
- **FunctionCallDelta**: `name: String?`, `arguments: String?`
- **Conformance**: `Codable`, `Sendable`

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
- **run()**: Accepts model, messages, config; returns `ToolSessionResult`
- **Loop logic**: Parallel tool execution via `withThrowingTaskGroup`

### ToolSessionResult (struct)
Result of a ToolSession run.

- **Fields**: `response: ChatResponse`, `messages: [any ChatMessage]`, `iterations: Int`, `log: [ToolCallLogEntry]`

### ToolCallLogEntry (struct)
Log entry for a single tool call execution.

- **Fields**: `name: String`, `arguments: String`, `result: String`, `duration: Duration`

### Agent (actor)
High-level persistent agent with conversation history, parallel tool execution, and transcript.

- **Init**: client, model, systemPrompt, tools, toolChoice, toolHandlers, config, maxToolIterations
- **Builder init**: Uses `@AgentToolBuilder` for declarative tool registration
- **Methods**: `send(_:)`, `reset()`
- **Properties**: `history`, `transcript`
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
| `ChatResponse` | Add `firstToolCalls`, `requiresToolExecution` |
| `ChatDelta` | Add `firstToolCallDeltas` |

## Backward Compatibility

- `Tool.Function` deprecated init with `[String: String]` preserved
- `ChatResponse.Message.content` stays `String` type; null decodes as `""`
- All new fields are optional/additive
- New `LLMError` cases work with existing `default` switches

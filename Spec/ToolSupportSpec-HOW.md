# Tool Support — Implementation Details

Public API spec: [ToolSupportSpec.md](ToolSupportSpec.md)

---

## File Structure

```
Sources/SwiftChatCompletionsDSL/
├── SwiftChatCompletionsDSL.swift    # Core types, messages, ChatRequest, LLMClient, ToolsBuilder
├── ToolSession.swift                 # SessionComponent, SessionBuilder, ToolSession, ToolSessionResult, ToolCallLogEntry
├── Agent.swift                       # Agent actor, AgentTool, AgentToolBuilder, TranscriptEntry
Sources/SwiftChatCompletionsDSLMacros/
├── MacrosBridge.swift                # Tools(), AgentTool bridge, JSONSchema/Tool conversions
```

## Key Implementation Decisions

1. **JSONSchema in core target**: Own definition (not reusing macros `JSONSchemaValue`) to keep core zero-dependency. Bridge target converts between them.

2. **Content null handling**: `ChatResponse.Message.content` stays `String`, never `String?`. Null from API decodes as `""`. This is 100% source-compatible with existing code.

3. **ToolSession is a struct**: Stateless — takes inputs, produces outputs. `LLMClient` (actor) handles thread safety.

4. **Agent is an actor**: Manages mutable conversation history; thread-safe by design.

5. **Parallel tool execution**: `withThrowingTaskGroup` when API returns multiple tool_calls.

6. **ToolHandler signature**: `@Sendable (String) async throws -> String` — raw JSON args in, string result out. Works for both manual and macro-based tools.

7. **ToolsBuilder**: Result builder for inline tool declarations in ChatRequest, supporting conditionals and loops.

8. **Duplicate tool detection**: `ToolSession` and `Agent` (explicit init) use `precondition` to catch duplicate tool names at creation time. `Agent` builder and declarative inits `throw` instead.

9. **ToolCallAccumulator**: Mutable struct for accumulating streaming tool call deltas into complete `ToolCall` objects, avoiding manual fragment tracking.

## ToolCallAccumulator Algorithm

### Internal State

Four dictionaries keyed by `Int` (the delta index):
- `ids: [Int: String]` — tool call IDs
- `types: [Int: String]` — tool call types
- `names: [Int: String]` — function names
- `arguments: [Int: String]` — accumulated argument strings

Plus a `maxIndex: Int` tracker initialized to `-1`.

### `append(_ delta: ToolCallDelta)`

1. If `delta.index > maxIndex`, update `maxIndex`.
2. If `delta.id` is non-nil, store/overwrite `ids[index]`.
3. If `delta.type` is non-nil, store/overwrite `types[index]`.
4. If `delta.function` is non-nil:
   a. If `function.name` is non-nil, store/overwrite `names[index]`.
   b. If `function.arguments` is non-nil, **append** (not replace) to `arguments[index]` using `arguments[index, default: ""].append(args)`. This handles chunked streaming where arguments arrive in fragments.

### `toolCalls: [ToolCall]` (computed property)

1. If `maxIndex < 0`, return empty array.
2. Iterate `0...maxIndex`, using `compactMap`:
   a. Require both `ids[i]` and `names[i]` — skip index if either is missing.
   b. Use `types[i] ?? "function"` for the type (defaults if not received).
   c. Use `arguments[i] ?? ""` for the arguments (empty if no argument chunks received).
   d. Construct `ToolCall(id:type:function:)` with a `ToolCall.FunctionCall(name:arguments:)`.

### `reset()`

Clear all four dictionaries (`removeAll()`) and set `maxIndex = -1`.

## Core Types Location

| Type | Kind | Location |
|------|------|----------|
| `JSONSchema` | indirect enum | SwiftChatCompletionsDSL.swift |
| `ToolCall` | struct | SwiftChatCompletionsDSL.swift |
| `ToolCallDelta` | struct | SwiftChatCompletionsDSL.swift |
| `ToolChoice` | enum | SwiftChatCompletionsDSL.swift |
| `ToolChoiceParam` | struct | SwiftChatCompletionsDSL.swift |
| `AssistantToolCallMessage` | struct | SwiftChatCompletionsDSL.swift |
| `ToolResultMessage` | struct | SwiftChatCompletionsDSL.swift |
| `ToolsBuilder` | result builder | SwiftChatCompletionsDSL.swift |
| `ToolCallAccumulator` | struct | SwiftChatCompletionsDSL.swift |
| `SessionComponent` | enum | ToolSession.swift |
| `SessionBuilder` | result builder | ToolSession.swift |
| `ToolSession` | struct | ToolSession.swift |
| `ToolSessionResult` | struct | ToolSession.swift |
| `ToolCallLogEntry` | struct | ToolSession.swift |
| `Agent` | actor | Agent.swift |
| `AgentTool` | struct | Agent.swift |
| `AgentToolBuilder` | result builder | Agent.swift |
| `TranscriptEntry` | enum | Agent.swift |

## Macros Bridge: JSONSchema Conversion

`JSONSchema.init(from: JSONSchemaValue)` performs a direct case-by-case mapping from the macros package `JSONSchemaValue` enum to the core `JSONSchema` enum:

- `.object(properties, required)` → recursively convert each property value via `JSONSchema(from:)`, then create `.object(properties:required:)`
- `.array(items)` → recursively convert items via `JSONSchema(from:)`, then create `.array(items:)`
- `.string(description, enumValues)` → `.string(description:enumValues:)`
- `.integer(description, minimum, maximum)` → `.integer(description:minimum:maximum:)`
- `.number(description, minimum, maximum)` → `.number(description:minimum:maximum:)`
- `.boolean(description)` → `.boolean(description:)`

Note: `JSONSchemaValue` has no `.null` case, so no mapping is needed for that.

## Macros Bridge: Tool Conversion

`Tool.init(from: ToolDefinition)` maps:
- `definition.name` → `function.name`
- `definition.description` → `function.description`
- `definition.parameters` → recursively converted via `JSONSchema.init(from:)` → `function.parameters`
- `type` defaults to `"function"` (from `Tool.init` default parameter)

## Macros Bridge: AgentTool Conversion

`AgentTool.init<T: ChatCompletionsTool>(_ instance: T)`:

1. Gets `T.toolDefinition` (a static property on the protocol).
2. Creates a `Tool` from the definition via `Tool.init(from:)`.
3. Creates a handler closure that:
   a. Converts the JSON arguments string to `Data` via `.data(using: .utf8)` — throws `LLMError.decodingFailed` if conversion fails.
   b. Decodes `Data` into `T.Arguments` via `JSONDecoder`.
   c. Calls `instance.call(arguments:)` (async throws).
   d. Returns `output.content` (the string result).

`Tools<T: ChatCompletionsTool>(_ instance: T) -> AgentTool` is a thin convenience function that calls `AgentTool(instance)` — intended for `@SessionBuilder` blocks where the `Tools(...)` syntax reads naturally alongside `System(...)` and other message functions.

## Backward Compatibility

| Change | Strategy |
|--------|----------|
| `Tool.Function.parameters` type | Deprecated `[String: String]` init preserved |
| `ChatResponse.Message.content` | Null → `""`, keeps `String` |
| New optional fields | Additive only |
| New `LLMError` cases | Additive; existing `default` switches work |
| New message types (`System`, `User`, `UserMessage`, `Assistant` functions) | Additive convenience; `TextMessage` unchanged |
| `User` config struct → `UserID` | Renamed |
| New ChatRequest inits with `tools:` | Additive; existing inits unchanged |
| `SessionBuilder`, `SessionComponent` | New types; no existing API affected |
| ToolSession declarative init + `run(_:)` | Additive; explicit init and `run(model:messages:)` unchanged |
| Agent declarative init + `run(_:)` | Additive; explicit/builder inits and `send(_:)` unchanged |
| `Tools()` bridge function | Additive; `AgentTool.init<T>` unchanged |

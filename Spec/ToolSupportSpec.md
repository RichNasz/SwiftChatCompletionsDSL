# Tool Support Specification

## Overview

This specification describes the complete tool calling and agent support in SwiftChatCompletionsDSL. The DSL provides Apple FoundationModels-style ergonomics for defining tools, executing tool-calling loops, and building persistent agents — all targeting any OpenAI-compatible backend.

---

## WHAT — Public API

### Convenience Message Types

Shorthand constructors for common message roles:

```swift
System("You are a helpful assistant.")   // TextMessage(role: .system, content: ...)
UserMessage("What's the weather?")       // TextMessage(role: .user, content: ...)
Assistant("The weather is sunny.")       // TextMessage(role: .assistant, content: ...)
```

These work anywhere `TextMessage` works, including `@ChatBuilder` blocks. `Assistant()` is useful for building conversation history and few-shot examples.

### Macro-Powered Tools (via SwiftChatCompletionsMacros)

Using the companion macros package for zero-boilerplate tool definitions:

```swift
@Tool("get_current_weather")
struct GetCurrentWeather {
    @Generable
    struct Arguments {
        @Guide(description: "City and state, e.g. Alpharetta, GA")
        var location: String
        @Guide(description: "Unit", .anyOf(["celsius", "fahrenheit"]))
        var unit: String = "celsius"
    }

    func call(arguments: Arguments) async throws -> String { ... }
}
```

Bridged to core DSL types via `SwiftChatCompletionsDSLMacros` target:
- `AgentTool.init<T: ChatCompletionsTool>(_ instance: T)`
- `Tool.init(from: ToolDefinition)`

### Manual Tool Definition (JSONSchema)

```swift
let weatherTool = Tool(function: Tool.Function(
    name: "get_weather",
    description: "Get current weather for a location",
    parameters: .object(
        properties: [
            "location": .string(description: "City and state"),
            "unit": .string(description: "Unit", enumValues: ["celsius", "fahrenheit"]),
        ],
        required: ["location"]
    )
))
```

### ChatRequest with Tools

```swift
let request = try ChatRequest(model: "gpt-4o", toolChoice: .auto) {
    try Temperature(0.2)
} tools: {
    weatherTool
    calculatorTool
} messages: {
    System("You are a helpful assistant.")
    User("Weather in Alpharetta?")
}
```

### ToolCall.decodeArguments() — Typed Argument Decoding

```swift
struct WeatherArgs: Decodable {
    let location: String
    let unit: String
}

let args: WeatherArgs = try toolCall.decodeArguments()
```

Handles UTF-8 conversion safely and wraps errors as `LLMError.decodingFailed`.

### ToolCallAccumulator — Streaming Tool Call Assembly

```swift
var accumulator = ToolCallAccumulator()
for await delta in client.stream(request) {
    if let toolCallDeltas = delta.firstToolCallDeltas {
        for tcd in toolCallDeltas {
            accumulator.append(tcd)
        }
    }
}
let completedToolCalls = accumulator.toolCalls
```

Accumulates partial `ToolCallDelta` chunks into complete `ToolCall` objects. Supports parallel tool calls (multiple indices) and provides `reset()` for reuse.

### ToolSession — Automatic Tool Execution

```swift
// Basic usage with handlers dictionary
let session = ToolSession(
    client: client,
    tools: [weatherTool],
    handlers: ["get_weather": { args in
        return "{\"temperature\": 72, \"condition\": \"sunny\"}"
    }]
)

let result = try await session.run(
    model: "gpt-4o",
    messages: [UserMessage("Weather in Paris?")]
)
print(result.response.firstContent ?? "")
```

Duplicate tool names trigger a `precondition` failure. Handler errors are wrapped as `LLMError.toolExecutionFailed` with the error type name included for debugging.

### Agent — Persistent Conversations

```swift
let agent = try Agent(
    client: client,
    model: "gpt-4o",
    systemPrompt: "You are a helpful assistant."
) {
    try Temperature(0.7)
} tools: {
    AgentTool(tool: weatherTool) { args in
        return "{\"temperature\": 72}"
    }
}

let response1 = try await agent.send("Weather in Paris?")
let response2 = try await agent.send("How about London?")

// Debugging transcript
for entry in await agent.transcript { ... }

// Tool introspection
let names = await agent.registeredToolNames  // ["get_weather"]
let count = await agent.toolCount            // 1

// Reset for new conversation
await agent.reset()
```

Duplicate tool names in the builder init throw `LLMError.invalidValue`. The explicit init uses a `precondition`.

### Error Handling

```swift
catch LLMError.maxIterationsExceeded(let max) { ... }
catch LLMError.unknownTool(let name) { ... }
catch LLMError.toolExecutionFailed(let name, let message) { ... }
```

---

## HOW — Implementation Details

### File Structure

```
Sources/SwiftChatCompletionsDSL/
├── SwiftChatCompletionsDSL.swift    # Core types, messages, ChatRequest, LLMClient
├── ToolSession.swift                 # ToolSession, ToolSessionResult, ToolCallLogEntry
├── Agent.swift                       # Agent actor, AgentTool, AgentToolBuilder, TranscriptEntry
```

### Key Implementation Decisions

1. **JSONSchema in core target**: Own definition (not reusing macros `JSONSchemaValue`) to keep core zero-dependency. Bridge target converts between them.

2. **Content null handling**: `ChatResponse.Message.content` stays `String`, never `String?`. Null from API decodes as `""`. This is 100% source-compatible with existing code.

3. **ToolSession is a struct**: Stateless — takes inputs, produces outputs. `LLMClient` (actor) handles thread safety.

4. **Agent is an actor**: Manages mutable conversation history; thread-safe by design.

5. **Parallel tool execution**: `withThrowingTaskGroup` when API returns multiple tool_calls.

6. **ToolHandler signature**: `@Sendable (String) async throws -> String` — raw JSON args in, string result out. Works for both manual and macro-based tools.

7. **ToolsBuilder**: Result builder for inline tool declarations in ChatRequest, supporting conditionals and loops.

8. **Duplicate tool detection**: `ToolSession` and `Agent` (explicit init) use `precondition` to catch duplicate tool names at creation time. `Agent` builder init `throws` instead.

9. **ToolCallAccumulator**: Stateless struct for accumulating streaming tool call deltas into complete `ToolCall` objects, avoiding manual fragment tracking.

### Core Types

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
| `ToolSession` | struct | ToolSession.swift |
| `ToolSessionResult` | struct | ToolSession.swift |
| `ToolCallLogEntry` | struct | ToolSession.swift |
| `Agent` | actor | Agent.swift |
| `AgentTool` | struct | Agent.swift |
| `AgentToolBuilder` | result builder | Agent.swift |
| `TranscriptEntry` | enum | Agent.swift |

### Backward Compatibility

| Change | Strategy |
|--------|----------|
| `Tool.Function.parameters` type | Deprecated `[String: String]` init preserved |
| `ChatResponse.Message.content` | Null → `""`, keeps `String` |
| New optional fields | Additive only |
| New `LLMError` cases | Additive; existing `default` switches work |
| New message types (`System`, `UserMessage`, `Assistant` functions) | Additive convenience; `TextMessage` unchanged |
| New ChatRequest inits with `tools:` | Additive; existing inits unchanged |

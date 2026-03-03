# Tool Support Specification

## Overview

This specification describes the complete tool calling and agent support in SwiftChatCompletionsDSL. The DSL provides Apple FoundationModels-style ergonomics for defining tools, executing tool-calling loops, and building persistent agents — all targeting any OpenAI-compatible backend.

---

### Convenience Message Types

Shorthand constructors for common message roles:

```swift
System("You are a helpful assistant.")   // TextMessage(role: .system, content: ...)
User("What's the weather?")             // TextMessage(role: .user, content: ...)
UserMessage("What's the weather?")       // TextMessage(role: .user, content: ...) — retained for compatibility
Assistant("The weather is sunny.")       // TextMessage(role: .assistant, content: ...)
```

These work anywhere `TextMessage` works, including `@ChatBuilder` and `@SessionBuilder` blocks. `User()` is the preferred shorthand (coexists with the `UserID` config parameter because Swift resolves by return type in builder context). `UserMessage()` is retained for compatibility. `Assistant()` is useful for building conversation history and few-shot examples.

### Macro-Powered Tools (via SwiftChatCompletionsMacros)

Using the companion macros package for zero-boilerplate tool definitions:

```swift
/// Get the current weather for a location
@ChatCompletionsTool
struct GetCurrentWeather {
    @ChatCompletionsToolArguments
    struct Arguments {
        @ChatCompletionsToolGuide(description: "City and state, e.g. Alpharetta, GA")
        var location: String
        @ChatCompletionsToolGuide(description: "Unit", .anyOf(["celsius", "fahrenheit"]))
        var unit: String = "celsius"
    }

    func call(arguments: Arguments) async throws -> ToolOutput {
        ToolOutput(content: "...")
    }
}
```

Bridged to core DSL types via `SwiftChatCompletionsDSLMacros` target:
- `AgentTool.init<T: ChatCompletionsTool>(_ instance: T)`
- `Tool.init(from: ToolDefinition)`
- `Tools<T: ChatCompletionsTool>(_ instance: T) -> AgentTool` — convenience for `@SessionBuilder` blocks:
  ```swift
  let agent = try Agent(client: client, model: "gpt-4") {
      System("You are a helpful assistant.")
      Tools(GetCurrentWeather())
  }
  ```

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
    User("Weather in Alpharetta?")     // User() convenience function
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

**Declarative style** (preferred):
```swift
let session = ToolSession(client: client, model: "gpt-4o") {
    System("You are a weather assistant.")
    AgentTool(tool: weatherTool) { args in
        return "{\"temperature\": 72, \"condition\": \"sunny\"}"
    }
}

let result = try await session.run("Weather in Paris?")
print(result.response.firstContent ?? "")
```

**Explicit style**:
```swift
let session = ToolSession(
    client: client,
    tools: [weatherTool],
    handlers: ["get_weather": { args in
        return "{\"temperature\": 72, \"condition\": \"sunny\"}"
    }]
)

let result = try await session.run(
    model: "gpt-4o",
    messages: [User("Weather in Paris?")]
)
print(result.response.firstContent ?? "")
```

Duplicate tool names trigger a `precondition` failure. Handler errors are wrapped as `LLMError.toolExecutionFailed` with the error type name included for debugging.

### Agent — Persistent Conversations

**Declarative style** (preferred):
```swift
let agent = try Agent(client: client, model: "gpt-4o") {
    System("You are a helpful assistant.")
    AgentTool(tool: weatherTool) { args in
        return "{\"temperature\": 72}"
    }
}

let response1: String = try await agent.run("Weather in Paris?")
let response2: String = try await agent.run("How about London?")
```

**Builder style** (with config parameters):
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

let response1: String = try await agent.send("Weather in Paris?")
let response2: String = try await agent.send("How about London?")
```

**Common features** (both styles):
```swift
// Debugging transcript
for entry in await agent.transcript { ... }

// Tool introspection
let names = await agent.registeredToolNames  // ["get_weather"]
let count = await agent.toolCount            // 1

// Reset for new conversation (clears both conversation history AND transcript)
await agent.reset()
```

Both `send(_:)` and `run(_:)` return `String` (the assistant's text response). `run(_:)` is an alias for `send(_:)`. `reset()` clears conversation history and transcript. Duplicate tool names in the builder/declarative init throw `LLMError.invalidValue`. The explicit init uses a `precondition`.

### Error Handling

```swift
catch LLMError.maxIterationsExceeded(let max) { ... }
catch LLMError.unknownTool(let name) { ... }
catch LLMError.toolExecutionFailed(let name, let message) { ... }
```

For implementation details, see [ToolSupportSpec-HOW.md](ToolSupportSpec-HOW.md).

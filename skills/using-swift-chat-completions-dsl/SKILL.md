---
name: using-swift-chat-completions-dsl
description: >
  Helps the agent use SwiftChatCompletionsDSL to build type-safe LLM request pipelines with
  tool calling, sessions, and persistent agents for any OpenAI-compatible API. Useful when
  defining chat completions requests, wiring LLMTool instances into a ToolSession or Agent,
  handling multi-turn conversations, or processing streaming responses in Swift.
---

# Using SwiftChatCompletionsDSL

## Installation

Add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/RichNasz/SwiftChatCompletionsDSL.git", from: "1.0.0"),
    .package(url: "https://github.com/RichNasz/SwiftLLMToolMacros.git", from: "0.1.0")
]
```

Target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        "SwiftChatCompletionsDSL",
        "SwiftLLMToolMacros"
    ]
)
```

Imports at the top of each file:

```swift
import SwiftChatCompletionsDSL
import SwiftLLMToolMacros  // for @LLMTool, @LLMToolArguments, @LLMToolGuide
```

## LLMClient

```swift
let client = try LLMClient(
    baseURL: "https://api.openai.com/v1/chat/completions",
    apiKey: "your-api-key"
)
```

## Basic Request

```swift
let request = try ChatRequest(model: "gpt-4o") {
    try Temperature(0.7)
    try MaxTokens(500)
} messages: {
    System("You are a helpful assistant.")
    User("Explain async/await in Swift.")
}

let response = try await client.complete(request)
print(response.firstContent ?? "")
```

## Tool Calling

### Defining Tools

**Macro-powered (recommended):** Use `@LLMTool` from SwiftLLMToolMacros. The struct must have an `Arguments` type and a `call(arguments:)` method.

```swift
/// Get the current weather for a location.
@LLMTool
struct GetWeather {
    @LLMToolArguments
    struct Arguments {
        @LLMToolGuide(description: "City and state, e.g. San Francisco, CA")
        var location: String

        @LLMToolGuide(description: "Temperature unit", .anyOf(["celsius", "fahrenheit"]))
        var unit: String?
    }

    func call(arguments: Arguments) async throws -> ToolOutput {
        ToolOutput(content: "{\"temperature\": \"72F\"}")
    }
}
```

**Manual:** Construct a `Tool` directly.

```swift
let weatherTool = Tool(function: Tool.Function(
    name: "get_weather",
    description: "Get current weather for a city",
    parameters: .object(
        properties: ["city": .string(description: "City name")],
        required: ["city"]
    )
))
```

### AgentTool — Bridging a Tool to a Session

`AgentTool` pairs a tool definition with its handler. Two initializers:

```swift
// From an @LLMTool instance (recommended)
AgentTool(GetWeather())

// From a manual Tool with a handler closure
AgentTool(tool: weatherTool) { argumentsJSON in
    return "{\"temperature\": \"72F\"}"
}
```

The `ToolHandler` type is `@Sendable (String) async throws -> String`. The argument is the raw JSON arguments string from the model.

## ToolSession

`ToolSession` handles the tool-calling loop automatically, sending tool results back until the model produces a final response.

### Declarative Init (recommended)

```swift
let session = ToolSession(client: client, model: "gpt-4o") {
    System("You are a weather assistant.")
    AgentTool(GetWeather())
    AgentTool(tool: calculatorTool) { args in
        return "{\"result\": 42}"
    }
}

let result = try await session.run("What's the weather in Paris?")
print(result.response.firstContent ?? "")
```

### Explicit Init

```swift
let session = ToolSession(
    client: client,
    tools: [weatherTool],
    handlers: ["get_weather": { args in "{\"temperature\": \"72F\"}" }]
)

let result = try await session.run(
    model: "gpt-4o",
    messages: [User("What's the weather in Paris?")]
)
```

`session.run(_ prompt: String)` is only available on the declarative init. Use `session.run(model:messages:)` with the explicit init.

### Streaming

```swift
let stream = session.stream("What's the weather in Paris?")
for try await event in stream {
    switch event {
    case .textDelta(let text):      print(text, terminator: "")
    case .toolStarted(let name):    print("\n[calling \(name)]")
    case .toolCompleted(let name, _, _): print("[done: \(name)]")
    case .modelResponse(let r):     break
    case .completed(let result):    print("\nDone")
    }
}
```

### ToolSessionResult

```swift
result.response        // ModelResponse — final response from the model
result.messages        // [any ChatMessage] — full message history including tool turns
result.iterations      // Int — number of tool-calling rounds
result.log             // [(String, String)] — (toolName, result) pairs
```

## Agent

`Agent` is an actor that manages multi-turn conversation history and executes tools automatically.

### Declarative Init (recommended)

```swift
let agent = try Agent(client: client, model: "gpt-4o") {
    System("You are a helpful assistant with weather access.")
    AgentTool(GetWeather())
}

let reply1 = try await agent.run("What's the weather in Paris?")
let reply2 = try await agent.run("How about London?")  // agent remembers context
```

### Explicit Init

```swift
let agent = try Agent(
    client: client,
    model: "gpt-4o",
    systemPrompt: "You are a helpful assistant."
) {
    try Temperature(0.7)
} tools: {
    AgentTool(tool: weatherTool) { args in "{\"temperature\": \"72F\"}" }
}
```

### Agent Methods

```swift
agent.send(_ message: String)         // send a turn, returns String
agent.run(_ message: String)          // alias for send
agent.streamSend(_ message: String)   // returns AsyncThrowingStream<ToolSessionEvent, Error>
agent.reset()                         // clear history and transcript
```

### Transcript and History

```swift
for entry in await agent.transcript {
    switch entry {
    case .userMessage(let msg):               print("[User] \(msg)")
    case .assistantMessage(let msg):          print("[Assistant] \(msg)")
    case .toolCall(let name, let args):       print("[Tool] \(name)(\(args))")
    case .toolResult(let name, _, let dur):   print("[Result] \(name) in \(dur)s")
    case .error(let msg):                     print("[Error] \(msg)")
    }
}

let history = await agent.history  // [any ChatMessage] — full conversation history
```

## Configuration Parameters

All validate at construction time:

| Parameter | Range |
|---|---|
| `Temperature` | 0.0–2.0 |
| `MaxTokens` | 1–1,000,000 |
| `TopP` | 0.0–1.0 |
| `FrequencyPenalty` | -2.0–2.0 |
| `PresencePenalty` | -2.0–2.0 |
| `N` | 1–128 |
| `RequestTimeout` | 10–900s |
| `ResourceTimeout` | 30–3600s |

## Error Handling

```swift
do {
    let reply = try await agent.run("Hello")
} catch LLMError.rateLimit {
    // back off and retry
} catch LLMError.serverError(let code, let message) {
    print("HTTP \(code): \(message ?? "")")
} catch LLMError.networkError(let description) {
    print(description)
} catch LLMError.maxIterationsExceeded(let max) {
    print("Loop exceeded \(max) iterations")
} catch LLMError.unknownTool(let name) {
    print("Model called unregistered tool: \(name)")
} catch LLMError.toolExecutionFailed(let name, let message) {
    print("Tool \(name) failed: \(message)")
}
```

## Common Pitfalls

- **Old macro names** — The README shows `@ChatCompletionsTool`, `@ChatCompletionsToolArguments`, `@ChatCompletionsToolGuide`. These do not exist. Use `@LLMTool`, `@LLMToolArguments`, `@LLMToolGuide` from SwiftLLMToolMacros.
- **Explicit import** — Even though `SwiftLLMToolMacros` is a transitive dependency, you must `import SwiftLLMToolMacros` explicitly to use the macros.
- **`session.run(_ prompt:)` vs `session.run(model:messages:)`** — The single-string overload is only available on the declarative `@SessionBuilder` init. Explicit init requires `model:messages:`.
- **`agent.streamSend()`** — Streaming on Agent uses `streamSend`, not `stream`.
- **No `strict` parameter** — `AgentTool(instance)` in this DSL takes no `strict` argument. That parameter exists in SwiftOpenResponsesDSL only.
- **Duplicate tool names** — Agent and ToolSession both throw `LLMError.invalidValue` if you register two tools with the same name.

## Out of Scope

This skill covers SwiftChatCompletionsDSL wiring only. For designing `@LLMTool` structs, consult the `using-swift-llm-tool-macros` and `design-llm-tool` skills. For the Responses API, consult the `using-swift-open-responses-dsl` skill.

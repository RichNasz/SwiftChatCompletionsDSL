# SwiftChatCompletionsDSL

[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%2013.0+%20|%20iOS%2016.0+-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Built%20with-Claude%20Code-blueviolet.svg)](https://claude.ai/code)

> The only zero-dependency SwiftUI-style DSL with built-in Apple-native tool calling for any OpenAI-compatible backend

## Overview

SwiftChatCompletionsDSL is a modern Swift package that provides a **Domain Specific Language (DSL)** for interacting with Large Language Model (LLM) APIs. Instead of wrestling with complex JSON structures and manual request building, you can express your intent clearly and safely using Swift's powerful type system.

The DSL includes full **tool calling**, an automatic **ToolSession** loop, and a persistent **Agent** actor — bringing Apple FoundationModels-style ergonomics to any OpenAI-compatible endpoint.

### Before & After

**Traditional approach:**
```swift
// Complex, error-prone manual request building
var request = [String: Any]()
request["model"] = "gpt-4"
request["temperature"] = 0.7
request["max_tokens"] = 150
request["messages"] = [
    ["role": "system", "content": "You are helpful"],
    ["role": "user", "content": "Explain Swift"]
]
// No type safety, no validation, runtime crashes
```

**SwiftChatCompletionsDSL approach:**
```swift
// Clean, type-safe, declarative syntax
let request = try ChatRequest(model: "gpt-4") {
    try Temperature(0.7)
    try MaxTokens(150)
} messages: {
    System("You are helpful")
    User("Explain Swift")
}
```

### Key Benefits

- **Type Safety**: Compile-time validation prevents runtime errors
- **Declarative Syntax**: Self-documenting, readable code using result builders
- **Swift Concurrency**: Built with async/await and actors throughout
- **Tool Calling**: Full tool_calls parsing, parallel execution, automatic loops
- **Agent**: Persistent multi-turn conversations with automatic tool handling
- **Streaming Support**: Real-time response processing with AsyncThrowingStream
- **Timeout Control**: Configurable request and resource timeouts
- **Zero Dependencies**: Core library uses only Foundation
- **Any Backend**: Works with OpenAI, Azure, Ollama, LM Studio, or any compatible endpoint

## Quick Start

### Installation

Add SwiftChatCompletionsDSL to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/RichNasz/SwiftChatCompletionsDSL", from: "1.0.0")
]
```

For macro-powered tool definitions, also add the macros bridge:

```swift
// In your target dependencies:
.product(name: "SwiftChatCompletionsDSLMacros", package: "SwiftChatCompletionsDSL")
```

### Basic Usage

```swift
import SwiftChatCompletionsDSL

let client = try LLMClient(
    baseURL: "https://api.openai.com/v1/chat/completions",
    apiKey: "your-api-key"
)

let request = try ChatRequest(model: "gpt-4") {
    try Temperature(0.7)
    try MaxTokens(150)
} messages: {
    System("You are a helpful assistant.")
    User("Explain async/await in Swift.")
}

let response = try await client.complete(request)
print(response.firstContent ?? "No response")
```

## Tool Calling & Agents (Apple-style)

### Defining Tools with JSONSchema

```swift
let weatherTool = Tool(function: Tool.Function(
    name: "get_weather",
    description: "Get current weather for a location",
    parameters: .object(
        properties: [
            "location": .string(description: "City and state, e.g. San Francisco, CA"),
            "unit": .string(description: "Temperature unit", enumValues: ["celsius", "fahrenheit"]),
        ],
        required: ["location"]
    )
))
```

### Macro-Powered Tools (with SwiftChatCompletionsMacros)

For the most ergonomic tool definitions, use the companion [SwiftChatCompletionsMacros](https://github.com/RichNasz/SwiftChatCompletionsMacros) package:

```swift
import SwiftChatCompletionsDSLMacros
import SwiftChatCompletionsMacros

@ChatCompletionsToolArguments
struct WeatherArgs {
    @ChatCompletionsToolGuide(description: "City and state, e.g. Alpharetta, GA")
    var location: String

    @ChatCompletionsToolGuide(description: "Temperature unit", .anyOf(["celsius", "fahrenheit"]))
    var unit: String?
}

/// Get the current weather for a location
@ChatCompletionsTool
struct GetWeather {
    typealias Arguments = WeatherArgs

    func call(arguments: WeatherArgs) async throws -> ToolOutput {
        // Your weather API call here
        return ToolOutput(content: "{\"temperature\": 72}")
    }
}

// Bridge to AgentTool with one line:
let agentTool = AgentTool(GetWeather())
```

**Manual vs Macro — side-by-side comparison:**

| Aspect | Manual | Macro |
|--------|--------|-------|
| Parameter schema | Hand-write `JSONSchema` | Auto-generated from struct |
| Argument parsing | Manual JSON decode | Auto-decoded to typed struct |
| Tool name | Hand-write string | Auto-derived from type name |
| Description | Hand-write string | Extracted from doc comment |
| Lines of code | ~15 per tool | ~8 per tool |

### Inline Tools with Result Builder

```swift
let request = try ChatRequest(model: "gpt-4o", toolChoice: .auto) {
    try Temperature(0.2)
} tools: {
    weatherTool
    calculatorTool
} messages: {
    System("You are a helpful assistant.")
    User("What's the weather in Paris?")
}
```

### Manual Tool-Calling Loop

```swift
let response = try await client.complete(request)

if response.requiresToolExecution, let toolCalls = response.firstToolCalls {
    // Model wants to call tools — execute them and send results back
    for toolCall in toolCalls {
        print("Tool: \(toolCall.function.name)")
        print("Args: \(toolCall.function.arguments)")
    }
}
```

### ToolSession — Declarative Style

`ToolSession` handles the entire tool-calling loop automatically. The declarative init uses `@SessionBuilder` to mix system messages and tools in one block:

```swift
let session = ToolSession(client: client, model: "gpt-4o") {
    System("You are a weather assistant.")
    AgentTool(tool: weatherTool) { arguments in
        return "{\"temperature\": 72, \"condition\": \"sunny\"}"
    }
}

let result = try await session.run("What's the weather in Paris?")
print(result.response.firstContent ?? "")  // "The weather in Paris is 72°F and sunny."
```

<details>
<summary>Explicit init (alternative)</summary>

```swift
let session = ToolSession(
    client: client,
    tools: [weatherTool],
    handlers: ["get_weather": { arguments in
        return "{\"temperature\": 72, \"condition\": \"sunny\"}"
    }]
)

let result = try await session.run(
    model: "gpt-4o",
    messages: [User("What's the weather in Paris?")]
)
```
</details>

### Agent — Persistent Conversations with Tools

`Agent` is an actor that manages conversation history, automatically executes tools via `ToolSession`, and maintains a debugging transcript.

```swift
let agent = try Agent(client: client, model: "gpt-4o") {
    System("You are a helpful assistant with weather data access.")
    AgentTool(tool: weatherTool) { arguments in
        return "{\"temperature\": 72, \"condition\": \"sunny\"}"
    }
}

// Multi-turn — agent remembers history automatically
let response1 = try await agent.run("What's the weather in Paris?")
print(response1)  // "The weather in Paris is 72°F and sunny."

let response2 = try await agent.run("How about London?")
print(response2)  // "The weather in London is..."
```

<details>
<summary>Explicit init (alternative)</summary>

```swift
let agent = try Agent(
    client: client,
    model: "gpt-4o",
    systemPrompt: "You are a helpful assistant with weather data access."
) {
    try Temperature(0.7)
} tools: {
    AgentTool(tool: weatherTool) { arguments in
        return "{\"temperature\": 72, \"condition\": \"sunny\"}"
    }
}

let response = try await agent.send("What's the weather in Paris?")
```
</details>

#### Transcript Inspection

```swift
for entry in await agent.transcript {
    switch entry {
    case .userMessage(let msg):      print("[User] \(msg)")
    case .assistantMessage(let msg): print("[Assistant] \(msg)")
    case .toolCall(let name, _):     print("[Tool Call] \(name)")
    case .toolResult(let name, _, let duration):
        print("[Tool Result] \(name) (\(duration))")
    case .error(let msg):            print("[Error] \(msg)")
    }
}

// Reset when starting a new conversation
await agent.reset()
```

## Streaming

```swift
let request = try ChatRequest(model: "gpt-4", stream: true) {
    try Temperature(0.8)
    try MaxTokens(200)
} messages: {
    User("Write a haiku about Swift.")
}

for try await delta in client.stream(request) {
    if let content = delta.firstContent {
        print(content, terminator: "")
    }
}
```

## Conversation Management

```swift
var conversation = ChatConversation {
    System("You are a helpful tutor.")
}

conversation.addUser(content: "What is recursion?")
conversation.addAssistant(content: "Recursion is when a function calls itself...")
conversation.addUser(content: "Show me an example.")

// Tool call history support
conversation.addAssistantToolCalls(content: nil, toolCalls: toolCalls)
conversation.addToolResult(toolCallId: "call_123", content: "42")

let request = try conversation.request(model: "gpt-4") {
    try Temperature(0.7)
}
```

## Error Handling

```swift
do {
    let response = try await client.complete(request)
    print(response.firstContent ?? "No response")
} catch LLMError.rateLimit {
    print("Rate limited. Wait before retrying.")
} catch LLMError.serverError(let statusCode, let message) {
    print("Server error \(statusCode): \(message ?? "Unknown")")
} catch LLMError.networkError(let description) {
    print("Network error: \(description)")
} catch LLMError.maxIterationsExceeded(let max) {
    print("Tool-calling loop exceeded \(max) iterations")
} catch LLMError.unknownTool(let name) {
    print("Model called unregistered tool: \(name)")
} catch LLMError.toolExecutionFailed(let name, let message) {
    print("Tool \(name) failed: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Configuration Parameters

All parameters validate ranges at construction time:

| Parameter | Range | Description |
|-----------|-------|-------------|
| `Temperature` | 0.0 - 2.0 | Sampling temperature |
| `MaxTokens` | 1 - 1,000,000 | Maximum tokens to generate |
| `TopP` | 0.0 - 1.0 | Nucleus sampling |
| `FrequencyPenalty` | -2.0 - 2.0 | Frequency penalty |
| `PresencePenalty` | -2.0 - 2.0 | Presence penalty |
| `N` | 1 - 128 | Number of completions |
| `RequestTimeout` | 10 - 900s | HTTP request timeout |
| `ResourceTimeout` | 30 - 3600s | Total resource timeout |
| `ToolChoiceParam` | auto/none/required/function | Tool selection strategy |

## Package Structure

```
Products:
  SwiftChatCompletionsDSL          # Core library (zero dependencies)
  SwiftChatCompletionsDSLMacros    # Bridge to SwiftChatCompletionsMacros

Targets:
  SwiftChatCompletionsDSL          # Core (Foundation only)
  SwiftChatCompletionsDSLMacros    # Bridge target
  SwiftChatCompletionsDSLTests     # 120 tests
```

## Requirements

- **Swift**: 6.2 or later
- **Platforms**: macOS 13.0+, iOS 16.0+
- **Core Dependencies**: None (Foundation only)
- **Macros Bridge**: Requires [SwiftChatCompletionsMacros](https://github.com/RichNasz/SwiftChatCompletionsMacros)

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

## License

SwiftChatCompletionsDSL is released under the Apache 2.0 license. See [LICENSE](LICENSE) for details.

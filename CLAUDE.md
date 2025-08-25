# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Swift Package Manager project that implements `SwiftChatCompletionsDSL` - an embedded Swift DSL for communicating with LLM inference servers supporting OpenAI-compatible Chat Completions endpoints. The DSL provides a declarative, type-safe interface for both streaming and non-streaming chat completions.

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
- **Result Builders**: Uses `@ChatBuilder` for messages and `@ChatConfigBuilder` for optional parameters
- **Type Safety**: Enforces roles, parameters, and responses at compile time
- **Swift Concurrency**: Built with `async`/`await` and actors for thread-safe operations
- **Value Types**: Uses structs for performance and immutability

### Key Components

1. **LLMClient (Actor)**: Thread-safe client for API communication
   - Manages HTTP requests to OpenAI-compatible endpoints
   - Supports both streaming and non-streaming responses
   - Uses `nonisolated` streaming method for better usability

2. **Result Builders**:
   - `@ChatBuilder`: Composes message sequences with control flow support
   - `@ChatConfigBuilder`: Composes configuration parameters declaratively

3. **Protocol System**:
   - `ChatMessage`: Extensible protocol for different message types
   - `ChatConfigParameter`: Protocol for optional configuration parameters

4. **Configuration Structs**: Type-safe wrappers for API parameters with validation
   - `Temperature`, `MaxTokens`, `TopP`, `FrequencyPenalty`, `PresencePenalty`, etc.
   - Each validates input ranges and throws `LLMError.invalidValue(String)` on invalid values

5. **Conversation Management**:
   - `ChatConversation`: Utility for managing persistent conversation history
   - Supports both builder pattern and array-based message initialization

### JSON Serialization
- Uses `CodingKeys` to map Swift camelCase to OpenAI snake_case format
- Example: `maxTokens` → `max_tokens`, `topP` → `top_p`

### Error Handling
Custom `LLMError` enum covers:
- Invalid URLs, encoding/decoding failures
- Network errors, server errors with status codes
- Rate limiting (HTTP 429)
- Missing required fields (`baseURL`, `model`)
- Invalid parameter values with descriptive messages (`invalidValue(String)`)

### Swift Version Requirements
- **Minimum**: Swift 6.1+ (for trailing commas, `nonisolated`, improved type inference)
- **Testing Framework**: Swift Testing with `#expect` syntax
- **Concurrency**: Requires macOS 10.15+, iOS 13.0+ for async/await support

## Implementation Details

### URL Handling
- `baseURL` is treated as the complete endpoint URL (no path appending)
- Examples: `https://api.openai.com/v1/chat/completions`, `https://custom-server.com/chat`

### Streaming Support
- Parses Server-Sent Events (SSE) format
- Handles `data: [DONE]` termination signals
- Returns `AsyncStream<ChatDelta>` for real-time content streaming

### Extensibility
- Add custom message types by conforming to `ChatMessage`
- Add custom parameters by conforming to `ChatConfigParameter`
- Support for future multimodal content (images, etc.)

## Testing Strategy

The test suite uses Swift Testing framework and covers:
- Parameter validation and error cases
- Result builder functionality
- Conversation history management
- Async streaming operations (with mocked `URLSession`)
- JSON serialization/deserialization
- Edge cases (empty messages, rate limits)

## File Structure
```
Sources/SwiftChatCompletionsDSL/
├── SwiftChatCompletionsDSL.swift    # Main implementation
Tests/SwiftChatCompletionsDSLTests/
├── SwiftChatCompletionsDSLTests.swift   # Test cases
Spec/
├── SwiftChatCompletionsDSL.md       # Detailed specification
```

The project follows Swift Package Manager conventions with all implementation in a single source file for simplicity, though it could be split into multiple files as the codebase grows.
# Usage Examples

Practical examples and patterns for real-world applications with SwiftChatCompletionsDSL.

## For Beginners

If you're new to LLMs or Swift concurrency, start here. We'll build up from the simplest possible examples to more complex scenarios.

### Your First Request

The most basic chat completion request needs just a model and a message:

```swift
import SwiftChatCompletionsDSL

// Create a client
let client = try LLMClient(
    baseURL: "https://api.openai.com/v1/chat/completions",
    apiKey: "your-api-key"
)

// Create and send a simple request
let request = try ChatRequest(model: "gpt-4") {
    // No configuration parameters needed for basic use
} messages: {
    TextMessage(role: .user, content: "What is 2 + 2?")
}

let response = try await client.complete(request)
print(response.choices.first?.message.content ?? "No response")
```

**What's happening here?**
- We create an `LLMClient` with the OpenAI endpoint and your API key
- We build a `ChatRequest` specifying the model
- We add a single user message
- We send the request and print the response

### Adding Basic Configuration

Most real applications need some control over the AI's behavior:

```swift
let request = try ChatRequest(model: "gpt-4") {
    try Temperature(0.7)  // Controls creativity (0.0 = focused, 2.0 = very creative)
    try MaxTokens(100)    // Limits response length
} messages: {
    TextMessage(role: .user, content: "Write a short explanation of photosynthesis.")
}
```

**Key parameters for beginners:**
- **Temperature (0.0-2.0)**: Higher = more creative/random, lower = more focused/deterministic
- **MaxTokens**: Maximum words in the response (prevents overly long answers)

### Building Better Conversations

Real conversations need context. Use system messages to set the AI's behavior:

```swift
let request = try ChatRequest(model: "gpt-4") {
    try Temperature(0.5)    // Balanced for educational content
    try MaxTokens(200)
} messages: {
    TextMessage(role: .system, content: "You are a friendly tutor who explains things clearly and asks follow-up questions.")
    TextMessage(role: .user, content: "I'm confused about variables in programming.")
}
```

**System message tips:**
- Be specific about the AI's role and behavior
- Include the tone you want (friendly, professional, etc.)
- Mention if you want examples, questions, or specific formats

## Non-Streaming Examples

Non-streaming requests wait for the complete response before returning. Use these for:
- Simple Q&A applications
- When you need the full response to process it
- Batch processing scenarios

### Basic Question and Answer

```swift
func askQuestion(_ question: String) async throws -> String {
    let client = try LLMClient(
        baseURL: "https://api.openai.com/v1/chat/completions",
        apiKey: "your-api-key"
    )
    
    let request = try ChatRequest(model: "gpt-4") {
        try Temperature(0.3)  // Lower temperature for factual questions
        try MaxTokens(150)
    } messages: {
        TextMessage(role: .system, content: "You are a knowledgeable assistant. Provide accurate, concise answers.")
        TextMessage(role: .user, content: question)
    }
    
    let response = try await client.complete(request)
    return response.choices.first?.message.content ?? "No response received"
}

// Usage
let answer = try await askQuestion("What is the speed of light?")
print(answer)
```

### Code Analysis and Review

```swift
func reviewSwiftCode(_ code: String) async throws -> String {
    let client = try LLMClient(
        baseURL: "https://api.openai.com/v1/chat/completions",
        apiKey: "your-api-key"
    )
    
    let request = try ChatRequest(model: "gpt-4") {
        try Temperature(0.2)  // Low temperature for consistent analysis
        try MaxTokens(400)
    } messages: {
        TextMessage(role: .system, content: """
            You are a Swift programming expert. Review the provided code and:
            1. Identify any issues or improvements
            2. Suggest best practices
            3. Explain your reasoning clearly
            """)
        TextMessage(role: .user, content: "Please review this Swift code:\\n\\n```swift\\n\\(code)\\n```")
    }
    
    let response = try await client.complete(request)
    return response.choices.first?.message.content ?? "No review available"
}

// Usage
let codeToReview = """
func calculateArea(width: Int, height: Int) -> Int {
    return width * height
}
"""

let review = try await reviewSwiftCode(codeToReview)
print(review)
```

### Language Translation

```swift
func translateText(_ text: String, to language: String) async throws -> String {
    let client = try LLMClient(
        baseURL: "https://api.openai.com/v1/chat/completions",
        apiKey: "your-api-key"
    )
    
    let request = try ChatRequest(model: "gpt-4") {
        try Temperature(0.1)  // Very low for accurate translation
        try MaxTokens(300)
    } messages: {
        TextMessage(role: .system, content: "You are a professional translator. Provide accurate translations while preserving meaning and tone.")
        TextMessage(role: .user, content: "Translate the following text to \\(language):\\n\\n\\(text)")
    }
    
    let response = try await client.complete(request)
    return response.choices.first?.message.content ?? "Translation failed"
}

// Usage
let translation = try await translateText("Hello, how are you today?", to: "Spanish")
print(translation)
```

## Streaming Examples

Streaming provides real-time responses as the AI generates them. Use for:
- Interactive chat applications
- Long responses where users want to see progress
- Real-time user interfaces

### Basic Streaming Response

```swift
func streamResponse(to question: String) async throws {
    let client = try LLMClient(
        baseURL: "https://api.openai.com/v1/chat/completions",
        apiKey: "your-api-key"
    )
    
    let request = try ChatRequest(model: "gpt-4", stream: true) {  // Note: stream: true
        try Temperature(0.7)
        try MaxTokens(300)
    } messages: {
        TextMessage(role: .user, content: question)
    }
    
    print("AI: ", terminator: "")
    for await delta in client.stream(request) {
        if let content = delta.choices.first?.delta.content {
            print(content, terminator: "")
            fflush(stdout)  // Ensure immediate output
        }
        
        // Check if streaming is complete
        if let finishReason = delta.choices.first?.finishReason {
            print("\\n[Finished: \\(finishReason)]")
            break
        }
    }
    print()  // New line when done
}

// Usage
try await streamResponse(to: "Explain how neural networks work in simple terms.")
```

### Building a Chat Interface

```swift
class ChatSession {
    private let client: LLMClient
    private var conversationHistory: [any ChatMessage] = []
    
    init(apiKey: String) throws {
        self.client = try LLMClient(
            baseURL: "https://api.openai.com/v1/chat/completions",
            apiKey: apiKey
        )
        
        // Set initial system message
        conversationHistory.append(
            TextMessage(role: .system, content: "You are a helpful assistant.")
        )
    }
    
    func sendMessage(_ message: String) async throws {
        // Add user message to history
        conversationHistory.append(
            TextMessage(role: .user, content: message)
        )
        
        let request = try ChatRequest(model: "gpt-4", stream: true) {
            try Temperature(0.7)
            try MaxTokens(500)
        } messages: conversationHistory
        
        print("Assistant: ", terminator: "")
        var assistantResponse = ""
        
        for await delta in client.stream(request) {
            if let content = delta.choices.first?.delta.content {
                print(content, terminator: "")
                assistantResponse += content
                fflush(stdout)
            }
            
            if delta.choices.first?.finishReason != nil {
                break
            }
        }
        
        print()  // New line
        
        // Add assistant response to history
        conversationHistory.append(
            TextMessage(role: .assistant, content: assistantResponse)
        )
    }
}

// Usage
let chat = try ChatSession(apiKey: "your-api-key")
try await chat.sendMessage("Hi, I'm learning Swift!")
try await chat.sendMessage("Can you explain optionals?")
try await chat.sendMessage("Show me an example with error handling.")
```

## Configuration Parameter Usage

### Temperature: Controlling Creativity

```swift
// Factual, deterministic responses
let factualRequest = try ChatRequest(model: "gpt-4") {
    try Temperature(0.1)  // Very focused
} messages: {
    TextMessage(role: .user, content: "What is the capital of Japan?")
}

// Creative, varied responses
let creativeRequest = try ChatRequest(model: "gpt-4") {
    try Temperature(0.9)  // Very creative
} messages: {
    TextMessage(role: .user, content: "Write a poem about programming.")
}
```

### Token Management

```swift
// Short, concise responses
let briefRequest = try ChatRequest(model: "gpt-4") {
    try MaxTokens(50)  // Very brief
} messages: {
    TextMessage(role: .user, content: "Summarize photosynthesis in one sentence.")
}

// Detailed explanations
let detailedRequest = try ChatRequest(model: "gpt-4") {
    try MaxTokens(500)  // Allow detailed response
} messages: {
    TextMessage(role: .user, content: "Explain object-oriented programming in detail.")
}
```

### Advanced Parameter Combinations

```swift
let preciseRequest = try ChatRequest(model: "gpt-4") {
    try Temperature(0.2)           // Low creativity for precision
    try TopP(0.8)                  // Focus on most likely words
    try FrequencyPenalty(0.1)      // Reduce repetition
    try PresencePenalty(0.1)       // Encourage topic diversity
    try MaxTokens(300)
    try User("tutorial-user")      // Track usage analytics
} messages: {
    TextMessage(role: .system, content: "You are a technical writer. Be precise and avoid repetition.")
    TextMessage(role: .user, content: "Explain the difference between classes and structs in Swift.")
}
```

## Conversation Management Patterns

### Using ChatConversation for State Management

```swift
import SwiftChatCompletionsDSL

// Initialize a managed conversation
var conversation = ChatConversation {
    TextMessage(role: .system, content: "You are a helpful programming tutor.")
}

let client = try LLMClient(
    baseURL: "https://api.openai.com/v1/chat/completions",
    apiKey: "your-api-key"
)

// Function to continue the conversation
func continueConversation(with userMessage: String) async throws {
    // Add user message
    conversation.addUser(content: userMessage)
    
    // Generate request from conversation history
    let request = try conversation.request(model: "gpt-4") {
        try Temperature(0.7)
        try MaxTokens(200)
    }
    
    // Get response
    let response = try await client.complete(request)
    
    if let assistantMessage = response.choices.first?.message.content {
        print("You: \\(userMessage)")
        print("Assistant: \\(assistantMessage)")
        print("---")
        
        // Add assistant response to conversation
        conversation.addAssistant(content: assistantMessage)
    }
}

// Usage
try await continueConversation(with: "What's a variable in programming?")
try await continueConversation(with: "How do I declare one in Swift?")
try await continueConversation(with: "What about constants?")

print("Conversation has \\(conversation.history.count) total messages")
```

### Pre-built Conversation Contexts

```swift
func createTutorConversation() -> [any ChatMessage] {
    return [
        TextMessage(role: .system, content: "You are an expert Swift programmer and patient teacher."),
        TextMessage(role: .user, content: "I'm new to Swift programming."),
        TextMessage(role: .assistant, content: "Welcome! I'm here to help you learn Swift. What would you like to start with?"),
        TextMessage(role: .user, content: "What's the difference between var and let?")
    ]
}

// Use the pre-built context
let request = try ChatRequest(model: "gpt-4") {
    try Temperature(0.6)
} messages: createTutorConversation()
```

## Error Handling Examples

### Comprehensive Error Handling

```swift
func safeCompletion(question: String) async -> String {
    do {
        let client = try LLMClient(
            baseURL: "https://api.openai.com/v1/chat/completions",
            apiKey: "your-api-key"
        )
        
        let request = try ChatRequest(model: "gpt-4") {
            try Temperature(0.7)
            try MaxTokens(200)
        } messages: {
            TextMessage(role: .user, content: question)
        }
        
        let response = try await client.complete(request)
        return response.choices.first?.message.content ?? "No response received"
        
    } catch LLMError.invalidValue(let message) {
        return "Configuration error: \\(message)"
    } catch LLMError.rateLimit {
        return "Rate limit exceeded. Please try again later."
    } catch LLMError.serverError(let statusCode, let message) {
        return "Server error (\\(statusCode)): \\(message ?? "Unknown error")"
    } catch LLMError.networkError(let description) {
        return "Network error: \\(description)"
    } catch {
        return "Unexpected error: \\(error.localizedDescription)"
    }
}

// Usage - always returns a string, never throws
let result = await safeCompletion(question: "Explain Swift closures")
print(result)
```

### Retry Logic for Network Issues

```swift
func resilientCompletion(question: String, maxRetries: Int = 3) async throws -> String {
    let client = try LLMClient(
        baseURL: "https://api.openai.com/v1/chat/completions",
        apiKey: "your-api-key"
    )
    
    let request = try ChatRequest(model: "gpt-4") {
        try Temperature(0.7)
        try MaxTokens(200)
    } messages: {
        TextMessage(role: .user, content: question)
    }
    
    for attempt in 1...maxRetries {
        do {
            let response = try await client.complete(request)
            return response.choices.first?.message.content ?? "No response"
        } catch LLMError.networkError {
            if attempt == maxRetries {
                throw LLMError.networkError("Failed after \\(maxRetries) attempts")
            }
            // Wait before retrying (exponential backoff)
            try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
        } catch {
            // Don't retry for non-network errors
            throw error
        }
    }
    
    throw LLMError.networkError("Unexpected retry loop exit")
}
```

## Graduating to Advanced

Once you're comfortable with basic usage, explore these advanced patterns:

### Custom Message Types

```swift
// Create a custom message type for code snippets
struct CodeMessage: ChatMessage {
    let role: Role = .user
    let language: String
    let code: String
    
    private enum CodingKeys: String, CodingKey {
        case role, content
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode("```\\(language)\\n\\(code)\\n```", forKey: .content)
    }
}

// Usage
let request = try ChatRequest(model: "gpt-4") {
    try Temperature(0.3)
} messages: {
    TextMessage(role: .system, content: "You are a code reviewer.")
    CodeMessage(language: "swift", code: "func greet() { print(\\"Hello\\") }")
    TextMessage(role: .user, content: "Please review this function.")
}
```

### Custom Configuration Parameters

```swift
struct Timeout: ChatConfigParameter {
    let seconds: TimeInterval
    
    func apply(to request: inout ChatRequest) {
        // This would require extending ChatRequest to support custom timeouts
        // For demonstration purposes only
    }
}

// Usage in configuration block
let request = try ChatRequest(model: "gpt-4") {
    try Temperature(0.7)
    Timeout(seconds: 30)  // Custom parameter
} messages: {
    TextMessage(role: .user, content: "Long processing task...")
}
```

### Integration with Different LLM Providers

```swift
// Anthropic Claude
let claudeClient = try LLMClient(
    baseURL: "https://api.anthropic.com/v1/messages",
    apiKey: "your-anthropic-key"
)

// Local LLM server
let localClient = try LLMClient(
    baseURL: "http://localhost:8080/v1/chat/completions",
    apiKey: "not-needed-for-local"
)

// Azure OpenAI
let azureClient = try LLMClient(
    baseURL: "https://your-resource.openai.azure.com/openai/deployments/your-deployment/chat/completions?api-version=2023-12-01-preview",
    apiKey: "your-azure-key"
)
```

The DSL works consistently across different providers that support the OpenAI chat completions format, making it easy to switch between services or test with local models.

## Performance Tips

- **Reuse LLMClient instances** - They're thread-safe and designed for reuse
- **Use appropriate token limits** - Longer responses cost more and take longer
- **Choose temperature wisely** - Lower values are faster and more consistent
- **Batch related requests** - Send multiple questions in one conversation rather than separate requests
- **Stream for long responses** - Better user experience for lengthy outputs

## Related Documentation

- <doc:DSL> - Understanding Domain Specific Languages
- <doc:Architecture> - Technical implementation details
- <doc:SwiftChatCompletionsDSL> - Complete API reference
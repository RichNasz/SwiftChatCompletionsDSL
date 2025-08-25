# Domain Specific Language Guide

Learn Domain Specific Languages and how to use SwiftChatCompletionsDSL effectively.

## What is a Domain Specific Language?

A **Domain Specific Language (DSL)** is a specialized programming language designed for a specific problem domain. Unlike general-purpose languages like Swift or Python, DSLs provide focused, expressive syntax that makes complex operations simple and intuitive.

Think of DSLs as specialized tools: just as you wouldn't use a hammer to cut wood, you shouldn't use generic programming patterns for specialized tasks. DSLs provide the right tool for the job.

### Examples of DSLs You Might Know

- **SQL**: A DSL for database queries
- **CSS**: A DSL for styling web pages  
- **SwiftUI**: A DSL for building user interfaces
- **Regular Expressions**: A DSL for pattern matching

## Why Use a DSL for Chat Completions?

Working with LLM APIs typically involves building complex JSON structures, managing validation, and handling errors. This creates several problems:

### The Traditional Approach Problems

```swift
// Traditional approach: Error-prone and verbose
var requestDict = [String: Any]()
requestDict["model"] = "gpt-4"
requestDict["temperature"] = 0.7  // What if this is > 2.0? Runtime error!
requestDict["max_tokens"] = 150
requestDict["messages"] = [
    ["role": "system", "content": "You are helpful"],
    ["role": "user", "content": "Hello"]
    // Easy to make typos in "role" or forget required fields
]

// Manual JSON serialization
let jsonData = try JSONSerialization.data(withJSONObject: requestDict)
// Manual network request building...
```

**Problems:**
- ❌ No compile-time validation
- ❌ Easy to make typos
- ❌ No parameter validation
- ❌ Verbose and repetitive
- ❌ Hard to maintain

### The DSL Approach Benefits

```swift
// DSL approach: Clean, safe, and expressive
let request = try ChatRequest(model: "gpt-4") {
    try Temperature(0.7)  // Validates range at compile time!
    try MaxTokens(150)
} messages: {
    TextMessage(role: .system, content: "You are helpful")
    TextMessage(role: .user, content: "Hello")  // Type-safe roles!
}
```

**Benefits:**
- ✅ Compile-time validation
- ✅ Type safety prevents typos
- ✅ Parameter validation
- ✅ Readable and concise
- ✅ Easy to maintain and extend

## Getting Started: Your First DSL Request

Let's walk through building your first chat completion request step by step.

### Step 1: Understanding the Basic Structure

Every chat completion request has three essential parts:

1. **A model** - Which LLM to use
2. **Configuration** - How the model should behave  
3. **Messages** - The conversation to process

```swift
let request = try ChatRequest(model: "gpt-4") {
    // Configuration goes here
} messages: {
    // Messages go here
}
```

### Step 2: Adding Configuration

Configuration parameters control how the LLM behaves. Each parameter has validation built-in:

```swift
let request = try ChatRequest(model: "gpt-4") {
    try Temperature(0.7)      // Controls randomness (0.0-2.0)
    try MaxTokens(150)        // Maximum response length (> 0)
    try TopP(0.9)             // Nucleus sampling (0.0-1.0)
} messages: {
    // Messages will go here
}
```

**What happens if you provide invalid values?**

```swift
// This will throw an error at the 'try' line:
try Temperature(3.0)  // Error: Temperature must be between 0.0 and 2.0, got 3.0
```

The DSL catches these errors early, preventing runtime failures.

### Step 3: Building the Message Sequence

Messages represent the conversation. Each message has a role and content:

```swift
let request = try ChatRequest(model: "gpt-4") {
    try Temperature(0.7)
    try MaxTokens(150)
} messages: {
    TextMessage(role: .system, content: "You are a helpful programming assistant.")
    TextMessage(role: .user, content: "Explain what a function is in Swift.")
}
```

**Message Roles:**
- `.system` - Instructions for the AI's behavior
- `.user` - Input from the human user
- `.assistant` - Previous responses from the AI
- `.tool` - Tool/function call results (advanced)

### Step 4: Sending the Request

```swift
import SwiftChatCompletionsDSL

// Create a client
let client = try LLMClient(
    baseURL: "https://api.openai.com/v1/chat/completions",
    apiKey: "your-api-key"
)

// Send the request
let response = try await client.complete(request)

// Process the response
if let content = response.choices.first?.message.content {
    print("AI Response: \\(content)")
}
```

## Progressive Examples: From Simple to Advanced

### Beginner: Basic Question and Answer

```swift
let simpleRequest = try ChatRequest(model: "gpt-4") {
    try Temperature(0.5)  // Balanced creativity
} messages: {
    TextMessage(role: .user, content: "What is the capital of France?")
}
```

### Intermediate: Adding Context and Control

```swift
let contextualRequest = try ChatRequest(model: "gpt-4") {
    try Temperature(0.3)      // Lower for factual responses
    try MaxTokens(100)        // Keep response concise
    try TopP(0.8)             // Focus on most likely words
} messages: {
    TextMessage(role: .system, content: "You are a geography teacher. Provide clear, educational answers.")
    TextMessage(role: .user, content: "What is the capital of France?")
}
```

### Advanced: Multi-turn Conversation

```swift
let conversationRequest = try ChatRequest(model: "gpt-4") {
    try Temperature(0.7)
    try MaxTokens(200)
    try User("student-123")   // Track user for analytics
} messages: {
    TextMessage(role: .system, content: "You are a patient tutor.")
    TextMessage(role: .user, content: "I don't understand functions in programming.")
    TextMessage(role: .assistant, content: "A function is like a recipe - it takes ingredients (parameters) and produces a dish (return value). What specific part confuses you?")
    TextMessage(role: .user, content: "How do I call a function?")
}
```

## Using Control Flow in the DSL

One of the powerful features of SwiftChatCompletionsDSL is that you can use Swift's control flow naturally:

### Conditional Configuration

```swift
let isCreativeTask = true

let request = try ChatRequest(model: "gpt-4") {
    if isCreativeTask {
        try Temperature(0.9)      // High creativity
        try TopP(0.95)
    } else {
        try Temperature(0.1)      // Low creativity for factual tasks
        try TopP(0.5)
    }
    try MaxTokens(200)
} messages: {
    TextMessage(role: .user, content: "Write a poem about Swift programming.")
}
```

### Dynamic Message Building

```swift
let includeExamples = true
let userLevel = "beginner"

let request = try ChatRequest(model: "gpt-4") {
    try Temperature(0.5)
} messages: {
    TextMessage(role: .system, content: "You are a programming instructor.")
    
    if userLevel == "beginner" {
        TextMessage(role: .system, content: "Use simple language and avoid jargon.")
    }
    
    TextMessage(role: .user, content: "Explain Swift optionals.")
    
    if includeExamples {
        TextMessage(role: .system, content: "Always include practical code examples.")
    }
}
```

### Looping Over Data

```swift
let previousConversation = [
    ("user", "Hello"),
    ("assistant", "Hi! How can I help?"),
    ("user", "I'm learning Swift")
]

let request = try ChatRequest(model: "gpt-4") {
    try Temperature(0.7)
} messages: {
    TextMessage(role: .system, content: "You are a helpful assistant.")
    
    // Add conversation history
    for (role, content) in previousConversation {
        if role == "user" {
            TextMessage(role: .user, content: content)
        } else {
            TextMessage(role: .assistant, content: content)
        }
    }
    
    // Add new message
    TextMessage(role: .user, content: "Can you explain closures?")
}
```

## Common Patterns and Best Practices

### 1. Start Simple, Add Complexity Gradually

Begin with basic requests and add parameters as needed:

```swift
// Start simple
let basic = try ChatRequest(model: "gpt-4") {
} messages: {
    TextMessage(role: .user, content: "Hello")
}

// Add temperature for creativity
let withTemp = try ChatRequest(model: "gpt-4") {
    try Temperature(0.7)
} messages: {
    TextMessage(role: .user, content: "Write a creative story")
}

// Add more controls as needed
let fullyConfigured = try ChatRequest(model: "gpt-4") {
    try Temperature(0.7)
    try MaxTokens(500)
    try TopP(0.9)
    try FrequencyPenalty(0.1)
} messages: {
    TextMessage(role: .user, content: "Write a creative story")
}
```

### 2. Use System Messages Effectively

System messages set the AI's behavior. Be specific:

```swift
// ❌ Vague system message
TextMessage(role: .system, content: "Be helpful")

// ✅ Specific system message
TextMessage(role: .system, content: "You are a Swift programming expert. Provide accurate, concise answers with code examples when helpful. Explain complex concepts in simple terms.")
```

### 3. Handle Different Use Cases

```swift
// For factual questions: Low temperature
let factualRequest = try ChatRequest(model: "gpt-4") {
    try Temperature(0.1)
    try MaxTokens(100)
} messages: {
    TextMessage(role: .system, content: "Provide accurate, factual answers.")
    TextMessage(role: .user, content: "What is the boiling point of water?")
}

// For creative tasks: Higher temperature
let creativeRequest = try ChatRequest(model: "gpt-4") {
    try Temperature(0.8)
    try MaxTokens(300)
} messages: {
    TextMessage(role: .system, content: "You are a creative writer.")
    TextMessage(role: .user, content: "Write a short poem about coding.")
}
```

## Troubleshooting Common DSL Mistakes

### 1. Parameter Validation Errors

**Problem:**
```swift
// This will fail
try Temperature(3.0)  // Temperature must be 0.0-2.0
```

**Solution:**
```swift
// Use valid range
try Temperature(0.8)  // ✅ Valid
```

### 2. Forgetting `try` Keywords

**Problem:**
```swift
ChatRequest(model: "gpt-4") {
    Temperature(0.7)  // ❌ Missing 'try'
}
```

**Solution:**
```swift
ChatRequest(model: "gpt-4") {
    try Temperature(0.7)  // ✅ Include 'try'
}
```

### 3. Empty Messages Block

**Problem:**
```swift
ChatRequest(model: "gpt-4") {
    try Temperature(0.7)
} messages: {
    // ❌ Empty - no messages
}
```

**Solution:**
```swift
ChatRequest(model: "gpt-4") {
    try Temperature(0.7)
} messages: {
    TextMessage(role: .user, content: "Hello")  // ✅ At least one message
}
```

## Next Steps

Now that you understand the basics of DSLs and SwiftChatCompletionsDSL:

1. **Practice with simple requests** - Start with basic examples
2. **Experiment with parameters** - Try different temperature and token settings
3. **Build conversations** - Create multi-turn dialogues
4. **Explore streaming** - Try real-time responses
5. **Extend the DSL** - Create custom message types for your needs

The DSL grows with you - start simple and add complexity as your needs evolve. The type system will guide you and prevent common mistakes along the way.

### Related Reading

- <doc:Usage> - Practical examples for real-world scenarios
- <doc:Architecture> - Technical details of how the DSL works
- <doc:SwiftChatCompletionsDSL> - Complete API reference
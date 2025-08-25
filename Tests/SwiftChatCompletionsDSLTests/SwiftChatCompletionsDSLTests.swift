import Foundation
import Testing
@testable import SwiftChatCompletionsDSL

// MARK: - Basic ChatRequest Tests

@Test func testChatRequestBasicConfig() throws {
    let request = try ChatRequest(model: "test-model", config: {
        try Temperature(0.7)
        try MaxTokens(100)
    }, messages: [
        TextMessage(role: .user, content: "Test message")
    ])
    
    #expect(request.model == "test-model")
    #expect(request.temperature == 0.7)
    #expect(request.maxTokens == 100)
    #expect(request.messages.count == 1)
}

@Test func testChatRequestWithArrayMessages() throws {
    let history: [any ChatMessage] = [
        TextMessage(role: .system, content: "You are helpful."),
        TextMessage(role: .user, content: "Hello"),
        TextMessage(role: .assistant, content: "Hi there!")
    ]
    
    let request = try ChatRequest(model: "test-model", config: {
        try Temperature(0.5)
    }, messages: history)
    
    #expect(request.messages.count == 3)
    #expect(request.temperature == 0.5)
    #expect(request.model == "test-model")
}

@Test func testChatRequestEmptyModel() {
    #expect(throws: LLMError.missingModel) {
        try ChatRequest(model: "", messages: [])
    }
}

@Test func testChatRequestStreamFlag() throws {
    let request = try ChatRequest(model: "test-model", stream: true, messages: [
        TextMessage(role: .user, content: "Test streaming")
    ])
    
    #expect(request.stream == true)
    #expect(request.model == "test-model")
}

// MARK: - Parameter Validation Tests

@Test func testTemperatureValidation() throws {
    // Valid temperatures
    _ = try Temperature(0.0)
    _ = try Temperature(1.0)
    _ = try Temperature(2.0)
    
    // Invalid temperatures
    #expect(throws: (any Error).self) {
        try Temperature(-0.1)
    }
    #expect(throws: (any Error).self) {
        try Temperature(2.1)
    }
}

@Test func testMaxTokensValidation() throws {
    // Valid max tokens
    _ = try MaxTokens(1)
    _ = try MaxTokens(1000)
    
    // Invalid max tokens
    #expect(throws: (any Error).self) {
        try MaxTokens(0)
    }
    #expect(throws: (any Error).self) {
        try MaxTokens(-10)
    }
}

@Test func testTopPValidation() throws {
    // Valid top-p values
    _ = try TopP(0.0)
    _ = try TopP(0.5)
    _ = try TopP(1.0)
    
    // Invalid top-p values
    #expect(throws: (any Error).self) {
        try TopP(-0.1)
    }
    #expect(throws: (any Error).self) {
        try TopP(1.1)
    }
}

@Test func testFrequencyPenaltyValidation() throws {
    // Valid frequency penalty values
    _ = try FrequencyPenalty(-2.0)
    _ = try FrequencyPenalty(0.0)
    _ = try FrequencyPenalty(2.0)
    
    // Invalid frequency penalty values
    #expect(throws: (any Error).self) {
        try FrequencyPenalty(-2.1)
    }
    #expect(throws: (any Error).self) {
        try FrequencyPenalty(2.1)
    }
}

@Test func testUserValidation() throws {
    // Valid user values
    _ = try User("user123")
    _ = try User("a")
    
    // Invalid user values
    #expect(throws: (any Error).self) {
        try User("")
    }
}

@Test func testStopValidation() throws {
    // Valid stop values
    _ = try Stop(["\n"])
    _ = try Stop([".", "!", "?"])
    
    // Invalid stop values
    #expect(throws: (any Error).self) {
        try Stop([])
    }
}

// MARK: - ChatConversation Tests

@Test func testChatConversationHistory() throws {
    var conversation = ChatConversation()
    conversation.addUser(content: "Hello")
    conversation.addAssistant(content: "Hi there")
    
    #expect(conversation.history.count == 2)
    
    let request = try conversation.request(model: "test-model", config: {
        try Temperature(0.5)
    })
    
    #expect(request.messages.count == 2)
    #expect(request.model == "test-model")
    #expect(request.temperature == 0.5)
}

@Test func testChatConversationWithBuilder() throws {
    let conversation = ChatConversation {
        TextMessage(role: .system, content: "You are helpful.")
        TextMessage(role: .user, content: "Hello")
    }
    
    #expect(conversation.history.count == 2)
}

// MARK: - LLMClient Tests

@Test func testLLMClientInitValidation() throws {
    // Valid initialization
    _ = try LLMClient(baseURL: "https://api.openai.com/v1/chat/completions", apiKey: "sk-test")
    
    // Invalid initialization - empty baseURL
    #expect(throws: LLMError.missingBaseURL) {
        try LLMClient(baseURL: "", apiKey: "sk-test")
    }
}

@Test func testLLMClientCustomSessionConfiguration() throws {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30.0
    
    _ = try LLMClient(
        baseURL: "https://api.openai.com/v1/chat/completions",
        apiKey: "sk-test",
        sessionConfiguration: config
    )
    
    // Client should be successfully created
}

// MARK: - JSON Encoding Tests

@Test func testTextMessageEncoding() throws {
    let message = TextMessage(role: .user, content: "Hello world")
    let encoder = JSONEncoder()
    let data = try encoder.encode(message)
    
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(json?["role"] as? String == "user")
    #expect(json?["content"] as? String == "Hello world")
}

// MARK: - JSON Decoding Tests

@Test func testChatResponseDecoding() throws {
    let jsonString = """
    {
        "id": "chatcmpl-123",
        "object": "chat.completion",
        "created": 1677652288,
        "model": "gpt-4o",
        "choices": [
            {
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "Hello! How can I help you today?"
                },
                "finish_reason": "stop"
            }
        ],
        "usage": {
            "prompt_tokens": 10,
            "completion_tokens": 9,
            "total_tokens": 19
        }
    }
    """
    
    let data = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    let response = try decoder.decode(ChatResponse.self, from: data)
    
    #expect(response.id == "chatcmpl-123")
    #expect(response.object == "chat.completion")
    #expect(response.created == 1677652288)
    #expect(response.model == "gpt-4o")
    #expect(response.choices.count == 1)
    #expect(response.choices[0].index == 0)
    #expect(response.choices[0].message.role == Role.assistant)
    #expect(response.choices[0].message.content == "Hello! How can I help you today?")
    #expect(response.choices[0].finishReason == "stop")
    #expect(response.usage?.promptTokens == 10)
    #expect(response.usage?.completionTokens == 9)
    #expect(response.usage?.totalTokens == 19)
}

@Test func testChatDeltaDecoding() throws {
    let jsonString = """
    {
        "choices": [
            {
                "index": 0,
                "delta": {
                    "content": "Hello",
                    "role": "assistant"
                },
                "finish_reason": null
            }
        ]
    }
    """
    
    let data = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    let delta = try decoder.decode(ChatDelta.self, from: data)
    
    #expect(delta.choices.count == 1)
    #expect(delta.choices[0].index == 0)
    #expect(delta.choices[0].delta.content == "Hello")
    #expect(delta.choices[0].delta.role == Role.assistant)
    #expect(delta.choices[0].finishReason == nil)
}

// MARK: - Edge Cases

@Test func testEmptyMessages() throws {
    let request = try ChatRequest(model: "test-model", messages: [])
    #expect(request.messages.isEmpty)
    #expect(request.model == "test-model")
}

@Test func testMultipleConfigParameters() throws {
    let request = try ChatRequest(model: "test-model", config: {
        try Temperature(0.7)
        try MaxTokens(150)
        try TopP(0.9)
        try FrequencyPenalty(0.5)
        try PresencePenalty(-0.2)
        try N(2)
        try User("user123")
        LogitBias(["token": 1])
        try Stop(["\n", ".", "!"])
    }, messages: [
        TextMessage(role: .user, content: "Test all parameters")
    ])
    
    #expect(request.temperature == 0.7)
    #expect(request.maxTokens == 150)
    #expect(request.topP == 0.9)
    #expect(request.frequencyPenalty == 0.5)
    #expect(request.presencePenalty == -0.2)
    #expect(request.n == 2)
    #expect(request.user == "user123")
    #expect(request.logitBias?["token"] == 1)
    #expect(request.stop == ["\n", ".", "!"])
}

// MARK: - Tool Support Tests

@Test func testToolStructure() throws {
    let function = Tool.Function(
        name: "get_weather",
        description: "Get the current weather",
        parameters: ["location": "string"]
    )
    let tool = Tool(function: function)
    
    #expect(tool.type == "function")
    #expect(tool.function.name == "get_weather")
    #expect(tool.function.description == "Get the current weather")
}

@Test func testToolsParameter() throws {
    let tool = Tool(function: Tool.Function(
        name: "calculate",
        description: "Perform calculation",
        parameters: ["expression": "string"]
    ))
    
    let request = try ChatRequest(model: "test-model", config: {
        Tools([tool])
    }, messages: [
        TextMessage(role: .user, content: "Calculate 2+2")
    ])
    
    #expect(request.tools?.count == 1)
    #expect(request.tools?[0].function.name == "calculate")
}

// MARK: - Custom Message Extension Test

@Test func testCustomMessageExtension() throws {
    struct CustomMessage: ChatMessage {
        let role: Role
        let content: String
        let metadata: String
        
        private enum CodingKeys: String, CodingKey {
            case role, content, metadata
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(role, forKey: .role)
            try container.encode(content, forKey: .content)
            try container.encode(metadata, forKey: .metadata)
        }
    }
    
    let customMessage = CustomMessage(role: .user, content: "Hello", metadata: "extra-info")
    let request = try ChatRequest(model: "test-model", messages: [customMessage])
    
    #expect(request.messages.count == 1)
    #expect(request.messages[0].role == .user)
}
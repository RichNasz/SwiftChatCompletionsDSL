//
//  SwiftChatCompletionsDSLTests.swift
//  SwiftChatCompletionsDSL
//
//  Created by Richard Naszcyniec on 6/23/25.
//  Code assisted by AI
//

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

// MARK: - Timeout Configuration Tests

@Test func testRequestTimeoutValidation() throws {
    // Valid request timeouts
    _ = try RequestTimeout(10)
    _ = try RequestTimeout(120)
    _ = try RequestTimeout(900)

    // Invalid request timeouts - below minimum
    #expect(throws: (any Error).self) {
        try RequestTimeout(9)
    }

    // Invalid request timeouts - above maximum
    #expect(throws: (any Error).self) {
        try RequestTimeout(901)
    }

    // Invalid request timeouts - zero and negative
    #expect(throws: (any Error).self) {
        try RequestTimeout(0)
    }
    #expect(throws: (any Error).self) {
        try RequestTimeout(-10)
    }
}

@Test func testResourceTimeoutValidation() throws {
    // Valid resource timeouts
    _ = try ResourceTimeout(30)
    _ = try ResourceTimeout(300)
    _ = try ResourceTimeout(3600)

    // Invalid resource timeouts - below minimum
    #expect(throws: (any Error).self) {
        try ResourceTimeout(29)
    }

    // Invalid resource timeouts - above maximum
    #expect(throws: (any Error).self) {
        try ResourceTimeout(3601)
    }

    // Invalid resource timeouts - zero and negative
    #expect(throws: (any Error).self) {
        try ResourceTimeout(0)
    }
    #expect(throws: (any Error).self) {
        try ResourceTimeout(-30)
    }
}

@Test func testTimeoutParametersApplyToRequest() throws {
    let request = try ChatRequest(model: "test-model", config: {
        try RequestTimeout(120)
        try ResourceTimeout(300)
        try Temperature(0.7)
    }, messages: [
        TextMessage(role: .user, content: "Test timeout configuration")
    ])

    #expect(request.requestTimeout == 120)
    #expect(request.resourceTimeout == 300)
    #expect(request.temperature == 0.7)
    #expect(request.model == "test-model")
}

@Test func testTimeoutParametersIndividualApplication() throws {
    // Test only request timeout
    let requestOnly = try ChatRequest(model: "test-model", config: {
        try RequestTimeout(60)
    }, messages: [
        TextMessage(role: .user, content: "Test")
    ])

    #expect(requestOnly.requestTimeout == 60)
    #expect(requestOnly.resourceTimeout == nil)

    // Test only resource timeout
    let resourceOnly = try ChatRequest(model: "test-model", config: {
        try ResourceTimeout(180)
    }, messages: [
        TextMessage(role: .user, content: "Test")
    ])

    #expect(resourceOnly.requestTimeout == nil)
    #expect(resourceOnly.resourceTimeout == 180)
}

@Test func testTimeoutParametersWithOtherConfiguration() throws {
    let request = try ChatRequest(model: "test-model", config: {
        try Temperature(0.8)
        try MaxTokens(200)
        try RequestTimeout(90)
        try TopP(0.9)
        try ResourceTimeout(270)
        try User("test-user")
    }, messages: [
        TextMessage(role: .user, content: "Complex configuration test")
    ])

    #expect(request.temperature == 0.8)
    #expect(request.maxTokens == 200)
    #expect(request.requestTimeout == 90)
    #expect(request.topP == 0.9)
    #expect(request.resourceTimeout == 270)
    #expect(request.user == "test-user")
}

@Test func testNoTimeoutParametersLeaveRequestUnmodified() throws {
    let request = try ChatRequest(model: "test-model", config: {
        try Temperature(0.7)
        try MaxTokens(100)
    }, messages: [
        TextMessage(role: .user, content: "No timeout test")
    ])

    #expect(request.requestTimeout == nil)
    #expect(request.resourceTimeout == nil)
    #expect(request.temperature == 0.7)
    #expect(request.maxTokens == 100)
}

@Test func testTimeoutErrorMessages() {
    // Test request timeout error messages
    do {
        _ = try RequestTimeout(5)
        #expect(Bool(false), "Should have thrown error")
    } catch LLMError.invalidValue(let message) {
        #expect(message.contains("Request timeout must be between 10 and 900 seconds"))
        #expect(message.contains("got 5"))
    } catch {
        #expect(Bool(false), "Wrong error type thrown")
    }

    // Test resource timeout error messages
    do {
        _ = try ResourceTimeout(20)
        #expect(Bool(false), "Should have thrown error")
    } catch LLMError.invalidValue(let message) {
        #expect(message.contains("Resource timeout must be between 30 and 3600 seconds"))
        #expect(message.contains("got 20"))
    } catch {
        #expect(Bool(false), "Wrong error type thrown")
    }
}

@Test func testTimeoutConversationIntegration() throws {
    var conversation = ChatConversation {
        TextMessage(role: .system, content: "You are helpful.")
    }

    conversation.addUser(content: "Test with timeouts")

    let request = try conversation.request(model: "test-model", config: {
        try RequestTimeout(150)
        try ResourceTimeout(450)
        try Temperature(0.6)
    })

    #expect(request.requestTimeout == 150)
    #expect(request.resourceTimeout == 450)
    #expect(request.temperature == 0.6)
    #expect(request.messages.count == 2)
}

// MARK: - ChatRequest JSON Encoding Tests

@Test func testChatRequestEncoding() throws {
    let request = try ChatRequest(model: "gpt-4", config: {
        try Temperature(0.8)
        try MaxTokens(100)
        try TopP(0.95)
        try FrequencyPenalty(0.5)
        try PresencePenalty(-0.3)
    }, messages: [
        TextMessage(role: .system, content: "You are helpful."),
        TextMessage(role: .user, content: "Hello")
    ])

    let encoder = JSONEncoder()
    let data = try encoder.encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    // Verify model and stream
    #expect(json?["model"] as? String == "gpt-4")
    #expect(json?["stream"] as? Bool == false)

    // Verify snake_case conversion for parameters
    #expect(json?["temperature"] as? Double == 0.8)
    #expect(json?["max_tokens"] as? Int == 100)
    #expect(json?["top_p"] as? Double == 0.95)
    #expect(json?["frequency_penalty"] as? Double == 0.5)
    #expect(json?["presence_penalty"] as? Double == -0.3)

    // Verify messages array
    let messages = json?["messages"] as? [[String: Any]]
    #expect(messages?.count == 2)
    #expect(messages?[0]["role"] as? String == "system")
    #expect(messages?[0]["content"] as? String == "You are helpful.")
    #expect(messages?[1]["role"] as? String == "user")
    #expect(messages?[1]["content"] as? String == "Hello")
}

@Test func testChatRequestStreamEncoding() throws {
    let request = try ChatRequest(model: "gpt-4", stream: true, messages: [
        TextMessage(role: .user, content: "Test")
    ])

    let encoder = JSONEncoder()
    let data = try encoder.encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["stream"] as? Bool == true)
}

@Test func testChatRequestOptionalFieldsOmitted() throws {
    let request = try ChatRequest(model: "gpt-4", messages: [
        TextMessage(role: .user, content: "Test")
    ])

    let encoder = JSONEncoder()
    let data = try encoder.encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    // Optional fields should not be present when nil
    #expect(json?["temperature"] == nil)
    #expect(json?["max_tokens"] == nil)
    #expect(json?["top_p"] == nil)
    #expect(json?["frequency_penalty"] == nil)
    #expect(json?["presence_penalty"] == nil)
    #expect(json?["n"] == nil)
    #expect(json?["stop"] == nil)
    #expect(json?["user"] == nil)
}

// MARK: - Role Encoding Tests

@Test func testRoleEncoding() throws {
    let encoder = JSONEncoder()

    let systemMessage = TextMessage(role: .system, content: "Test")
    let userData = try encoder.encode(systemMessage)
    let systemJson = try JSONSerialization.jsonObject(with: userData) as? [String: Any]
    #expect(systemJson?["role"] as? String == "system")

    let userMessage = TextMessage(role: .user, content: "Test")
    let userJson = try JSONSerialization.jsonObject(with: try encoder.encode(userMessage)) as? [String: Any]
    #expect(userJson?["role"] as? String == "user")

    let assistantMessage = TextMessage(role: .assistant, content: "Test")
    let assistantJson = try JSONSerialization.jsonObject(with: try encoder.encode(assistantMessage)) as? [String: Any]
    #expect(assistantJson?["role"] as? String == "assistant")

    let toolMessage = TextMessage(role: .tool, content: "Test")
    let toolJson = try JSONSerialization.jsonObject(with: try encoder.encode(toolMessage)) as? [String: Any]
    #expect(toolJson?["role"] as? String == "tool")
}

// MARK: - LLMError Tests

@Test func testLLMErrorEquality() {
    // Same errors should be equal
    #expect(LLMError.invalidURL == LLMError.invalidURL)
    #expect(LLMError.rateLimit == LLMError.rateLimit)
    #expect(LLMError.invalidResponse == LLMError.invalidResponse)
    #expect(LLMError.missingBaseURL == LLMError.missingBaseURL)
    #expect(LLMError.missingModel == LLMError.missingModel)

    // Errors with same associated values should be equal
    #expect(LLMError.encodingFailed("test") == LLMError.encodingFailed("test"))
    #expect(LLMError.decodingFailed("test") == LLMError.decodingFailed("test"))
    #expect(LLMError.networkError("test") == LLMError.networkError("test"))
    #expect(LLMError.invalidValue("test") == LLMError.invalidValue("test"))
    #expect(LLMError.serverError(statusCode: 500, message: "error") == LLMError.serverError(statusCode: 500, message: "error"))

    // Errors with different associated values should not be equal
    #expect(LLMError.encodingFailed("a") != LLMError.encodingFailed("b"))
    #expect(LLMError.serverError(statusCode: 500, message: nil) != LLMError.serverError(statusCode: 400, message: nil))

    // Different error types should not be equal
    #expect(LLMError.invalidURL != LLMError.rateLimit)
    #expect(LLMError.networkError("test") != LLMError.decodingFailed("test"))
}

// MARK: - Specific Error Type Assertions

@Test func testTemperatureThrowsInvalidValue() {
    #expect(throws: LLMError.invalidValue("Temperature must be between 0.0 and 2.0, got -0.1")) {
        try Temperature(-0.1)
    }
    #expect(throws: LLMError.invalidValue("Temperature must be between 0.0 and 2.0, got 2.5")) {
        try Temperature(2.5)
    }
}

@Test func testMaxTokensThrowsInvalidValue() {
    #expect(throws: LLMError.invalidValue("MaxTokens must be greater than 0, got 0")) {
        try MaxTokens(0)
    }
    #expect(throws: LLMError.invalidValue("MaxTokens must be greater than 0, got -5")) {
        try MaxTokens(-5)
    }
}

@Test func testTopPThrowsInvalidValue() {
    #expect(throws: LLMError.invalidValue("TopP must be between 0.0 and 1.0, got -0.1")) {
        try TopP(-0.1)
    }
    #expect(throws: LLMError.invalidValue("TopP must be between 0.0 and 1.0, got 1.5")) {
        try TopP(1.5)
    }
}

@Test func testUserThrowsInvalidValue() {
    #expect(throws: LLMError.invalidValue("User identifier cannot be empty")) {
        try User("")
    }
}

@Test func testStopThrowsInvalidValue() {
    #expect(throws: LLMError.invalidValue("Stop sequences array cannot be empty")) {
        try Stop([])
    }
}

// MARK: - PresencePenalty Validation Tests

@Test func testPresencePenaltyValidation() throws {
    // Valid presence penalty values
    _ = try PresencePenalty(-2.0)
    _ = try PresencePenalty(0.0)
    _ = try PresencePenalty(2.0)

    // Invalid presence penalty values
    #expect(throws: LLMError.invalidValue("PresencePenalty must be between -2.0 and 2.0, got -2.1")) {
        try PresencePenalty(-2.1)
    }
    #expect(throws: LLMError.invalidValue("PresencePenalty must be between -2.0 and 2.0, got 2.1")) {
        try PresencePenalty(2.1)
    }
}

// MARK: - N Parameter Validation Tests

@Test func testNParameterValidation() throws {
    // Valid N values
    _ = try N(1)
    _ = try N(5)
    _ = try N(100)

    // Invalid N values
    #expect(throws: LLMError.invalidValue("N must be greater than 0, got 0")) {
        try N(0)
    }
    #expect(throws: LLMError.invalidValue("N must be greater than 0, got -1")) {
        try N(-1)
    }
}

// MARK: - Tool Encoding Tests

@Test func testToolEncoding() throws {
    let function = Tool.Function(
        name: "get_weather",
        description: "Get weather for a location",
        parameters: ["location": "string", "unit": "celsius"]
    )
    let tool = Tool(function: function)

    let encoder = JSONEncoder()
    let data = try encoder.encode(tool)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["type"] as? String == "function")

    let functionJson = json?["function"] as? [String: Any]
    #expect(functionJson?["name"] as? String == "get_weather")
    #expect(functionJson?["description"] as? String == "Get weather for a location")

    let params = functionJson?["parameters"] as? [String: String]
    #expect(params?["location"] == "string")
    #expect(params?["unit"] == "celsius")
}

// MARK: - Mock URLProtocol for Network Tests

class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - LLMClient Network Tests (Serialized to avoid shared state conflicts)

@Suite(.serialized)
struct LLMClientNetworkTests {

    @Test func completeSuccess() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let responseJson = """
        {
            "id": "chatcmpl-test",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "Hello!"},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 5, "completion_tokens": 2, "total_tokens": 7}
        }
        """

        MockURLProtocol.requestHandler = { request in
            // Verify request headers
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseJson.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let request = try ChatRequest(model: "gpt-4", messages: [
            TextMessage(role: .user, content: "Hi")
        ])

        let response = try await client.complete(request)

        #expect(response.id == "chatcmpl-test")
        #expect(response.choices.count == 1)
        #expect(response.choices[0].message.content == "Hello!")
    }

    @Test func completeRateLimitError() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let request = try ChatRequest(model: "gpt-4", messages: [
            TextMessage(role: .user, content: "Hi")
        ])

        do {
            _ = try await client.complete(request)
            #expect(Bool(false), "Should have thrown rateLimit error")
        } catch LLMError.rateLimit {
            // Expected
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test func completeServerError() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, "Internal Server Error".data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let request = try ChatRequest(model: "gpt-4", messages: [
            TextMessage(role: .user, content: "Hi")
        ])

        do {
            _ = try await client.complete(request)
            #expect(Bool(false), "Should have thrown serverError")
        } catch LLMError.serverError(let statusCode, let message) {
            #expect(statusCode == 500)
            #expect(message == "Internal Server Error")
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test func invalidURL() async throws {
        // URL with spaces returns nil from URL(string:)
        let client = try LLMClient(
            baseURL: "https://invalid url with spaces",
            apiKey: "test-key"
        )

        let request = try ChatRequest(model: "gpt-4", messages: [
            TextMessage(role: .user, content: "Hi")
        ])

        do {
            _ = try await client.complete(request)
            #expect(Bool(false), "Should have thrown invalidURL error")
        } catch LLMError.invalidURL {
            // Expected
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    // MARK: - Stream Method Tests

    @Test func streamSuccess() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        // Simulate SSE stream with multiple deltas
        let sseData = """
        data: {"choices":[{"index":0,"delta":{"role":"assistant","content":"Hello"},"finish_reason":null}]}

        data: {"choices":[{"index":0,"delta":{"content":" world"},"finish_reason":null}]}

        data: {"choices":[{"index":0,"delta":{"content":"!"},"finish_reason":"stop"}]}

        data: [DONE]

        """

        MockURLProtocol.requestHandler = { request in
            // Verify streaming headers
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Accept") == "text/event-stream")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, sseData.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let request = try ChatRequest(model: "gpt-4", stream: true, messages: [
            TextMessage(role: .user, content: "Hi")
        ])

        var deltas: [ChatDelta] = []
        for try await delta in client.stream(request) {
            deltas.append(delta)
        }

        #expect(deltas.count == 3)
        #expect(deltas[0].choices[0].delta.content == "Hello")
        #expect(deltas[1].choices[0].delta.content == " world")
        #expect(deltas[2].choices[0].delta.content == "!")
        #expect(deltas[2].choices[0].finishReason == "stop")
    }

    @Test func streamRateLimitError() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let request = try ChatRequest(model: "gpt-4", stream: true, messages: [
            TextMessage(role: .user, content: "Hi")
        ])

        do {
            for try await _ in client.stream(request) {
                #expect(Bool(false), "Should not yield any deltas")
            }
            #expect(Bool(false), "Should have thrown rateLimit error")
        } catch LLMError.rateLimit {
            // Expected
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test func streamServerError() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let request = try ChatRequest(model: "gpt-4", stream: true, messages: [
            TextMessage(role: .user, content: "Hi")
        ])

        do {
            for try await _ in client.stream(request) {
                #expect(Bool(false), "Should not yield any deltas")
            }
            #expect(Bool(false), "Should have thrown serverError")
        } catch LLMError.serverError(let statusCode, _) {
            #expect(statusCode == 503)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test func streamInvalidURL() async throws {
        let client = try LLMClient(
            baseURL: "https://invalid url with spaces",
            apiKey: "test-key"
        )

        let request = try ChatRequest(model: "gpt-4", stream: true, messages: [
            TextMessage(role: .user, content: "Hi")
        ])

        do {
            for try await _ in client.stream(request) {
                #expect(Bool(false), "Should not yield any deltas")
            }
            #expect(Bool(false), "Should have thrown invalidURL error")
        } catch LLMError.invalidURL {
            // Expected
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test func streamEmptyResponse() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        // Just the DONE signal, no actual content
        let sseData = "data: [DONE]\n\n"

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, sseData.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let request = try ChatRequest(model: "gpt-4", stream: true, messages: [
            TextMessage(role: .user, content: "Hi")
        ])

        var deltas: [ChatDelta] = []
        for try await delta in client.stream(request) {
            deltas.append(delta)
        }

        #expect(deltas.isEmpty)
    }
}
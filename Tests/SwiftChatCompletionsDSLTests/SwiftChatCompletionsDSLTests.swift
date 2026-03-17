//
//  SwiftChatCompletionsDSLTests.swift
//  SwiftChatCompletionsDSL
//
//  Created by Richard Naszcyniec on 6/23/25.
//  Code assisted by AI
//

import Foundation
import Testing
import SwiftChatCompletionsMacros
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
    _ = try UserID("user123")
    _ = try UserID("a")
    
    // Invalid user values
    #expect(throws: (any Error).self) {
        try UserID("")
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
        try UserID("user123")
        try LogitBias(["token": 1])
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
    let tool = Tool(
        name: "get_weather",
        description: "Get the current weather",
        parameters: .object(properties: ["location": .string(description: "City name")], required: ["location"])
    )

    #expect(tool.name == "get_weather")
    #expect(tool.description == "Get the current weather")
}

@Test func testToolsParameter() throws {
    let tool = Tool(
        name: "calculate",
        description: "Perform calculation",
        parameters: .object(properties: ["expression": .string(description: "Math expression to evaluate")], required: ["expression"])
    )

    let request = try ChatRequest(model: "test-model", config: {
        Tools([tool])
    }, messages: [
        TextMessage(role: .user, content: "Calculate 2+2")
    ])

    #expect(request.tools?.count == 1)
    #expect(request.tools?[0].name == "calculate")
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
        try UserID("test-user")
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
        try UserID("")
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
    let tool = Tool(
        name: "get_weather",
        description: "Get weather for a location",
        parameters: .object(
            properties: [
                "location": .string(description: "The city name"),
                "unit": .string(description: "Temperature unit"),
            ],
            required: ["location"]
        )
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(tool)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["type"] as? String == "function")

    let functionJson = json?["function"] as? [String: Any]
    #expect(functionJson?["name"] as? String == "get_weather")
    #expect(functionJson?["description"] as? String == "Get weather for a location")

    let params = functionJson?["parameters"] as? [String: Any]
    #expect(params?["type"] as? String == "object")
    #expect(params?["additionalProperties"] as? Bool == false)

    let properties = params?["properties"] as? [String: Any]
    #expect(properties?["location"] != nil)
    #expect(properties?["unit"] != nil)

    let required = params?["required"] as? [String]
    #expect(required == ["location"])
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

// MARK: - All Network Tests (Serialized to avoid shared MockURLProtocol state)

@Suite(.serialized)
struct AllNetworkTests {

    // MARK: LLMClient Tests

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
        for try await delta in try await client.stream(request) {
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
            for try await _ in try await client.stream(request) {
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
            for try await _ in try await client.stream(request) {
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
            for try await _ in try await client.stream(request) {
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
        for try await delta in try await client.stream(request) {
            deltas.append(delta)
        }

        #expect(deltas.isEmpty)
    }

    @Test func completeDecodingFailed() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            // Return invalid JSON that cannot be decoded as ChatResponse
            let invalidJSON = Data("{ not valid json }".utf8)
            return (response, invalidJSON)
        }

        let client = try LLMClient(
            baseURL: "https://api.example.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let request = try ChatRequest(model: "test-model", messages: [
            TextMessage(role: .user, content: "Hello")
        ])

        await #expect(throws: LLMError.self) {
            try await client.complete(request)
        }
    }

    @Test func streamDecodingFailed() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        // SSE with malformed JSON in data line - streaming throws decodingFailed
        let malformedSSE = "data: { not valid json }\n\ndata: [DONE]\n\n"

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, malformedSSE.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let request = try ChatRequest(model: "gpt-4", stream: true, messages: [
            TextMessage(role: .user, content: "Hi")
        ])

        // The stream should throw decodingFailed when it encounters malformed JSON
        await #expect(throws: LLMError.self) {
            for try await _ in try await client.stream(request) {
                // Consume stream - should throw on malformed JSON
            }
        }
    }

// MARK: - Streaming Tool Call Integration Tests

    @Test func streamWithSingleToolCallDeltas() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let sseData = """
        data: {"choices":[{"index":0,"delta":{"role":"assistant","tool_calls":[{"index":0,"id":"call_abc","type":"function","function":{"name":"get_weather","arguments":""}}]},"finish_reason":null}]}

        data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"location\\""}}]},"finish_reason":null}]}

        data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":":\\"Paris\\"}"}}]},"finish_reason":null}]}

        data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}

        data: [DONE]

        """

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
            TextMessage(role: .user, content: "What's the weather in Paris?")
        ])

        var deltas: [ChatDelta] = []
        var accumulator = ToolCallAccumulator()
        for try await delta in try await client.stream(request) {
            deltas.append(delta)
            if let toolCallDeltas = delta.firstToolCallDeltas {
                for tcd in toolCallDeltas {
                    accumulator.append(tcd)
                }
            }
        }

        #expect(deltas.count == 4)
        let toolCalls = accumulator.toolCalls
        #expect(toolCalls.count == 1)
        #expect(toolCalls[0].id == "call_abc")
        #expect(toolCalls[0].function.name == "get_weather")
        #expect(toolCalls[0].function.arguments == "{\"location\":\"Paris\"}")
        #expect(deltas.last?.choices[0].finishReason == "tool_calls")
    }

    @Test func streamWithParallelToolCallDeltas() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let sseData = """
        data: {"choices":[{"index":0,"delta":{"role":"assistant","tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"get_weather","arguments":"{\\"city\\":\\"Paris\\"}"}},{"index":1,"id":"call_2","type":"function","function":{"name":"get_time","arguments":"{\\"tz\\":\\"UTC\\"}"}}]},"finish_reason":null}]}

        data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}

        data: [DONE]

        """

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
            TextMessage(role: .user, content: "What's the weather and time?")
        ])

        var accumulator = ToolCallAccumulator()
        for try await delta in try await client.stream(request) {
            if let toolCallDeltas = delta.firstToolCallDeltas {
                for tcd in toolCallDeltas {
                    accumulator.append(tcd)
                }
            }
        }

        let toolCalls = accumulator.toolCalls
        #expect(toolCalls.count == 2)
        #expect(toolCalls[0].id == "call_1")
        #expect(toolCalls[0].function.name == "get_weather")
        #expect(toolCalls[0].function.arguments == "{\"city\":\"Paris\"}")
        #expect(toolCalls[1].id == "call_2")
        #expect(toolCalls[1].function.name == "get_time")
        #expect(toolCalls[1].function.arguments == "{\"tz\":\"UTC\"}")
    }

// MARK: - JSONSchema Encoding Tests

@Test func testJSONSchemaObjectEncoding() throws {
    let schema = JSONSchema.object(
        properties: [
            "name": .string(description: "User name"),
            "age": .integer(description: "User age"),
        ],
        required: ["name"]
    )
    let data = try JSONEncoder().encode(schema)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["type"] as? String == "object")
    #expect(json?["additionalProperties"] as? Bool == false)
    #expect(json?["required"] as? [String] == ["name"])

    let properties = json?["properties"] as? [String: Any]
    #expect(properties?["name"] != nil)
    #expect(properties?["age"] != nil)
}

// MARK: - ToolCall Decoding Tests

@Test func testToolCallDecoding() throws {
    let json = """
    {
        "id": "call_abc123",
        "type": "function",
        "function": {
            "name": "get_weather",
            "arguments": "{\\"location\\": \\"Paris\\"}"
        }
    }
    """
    let data = json.data(using: .utf8)!
    let toolCall = try JSONDecoder().decode(ToolCall.self, from: data)

    #expect(toolCall.id == "call_abc123")
    #expect(toolCall.type == "function")
    #expect(toolCall.function.name == "get_weather")
    #expect(toolCall.function.arguments == "{\"location\": \"Paris\"}")
}

// MARK: - ToolCallDelta Decoding Tests

@Test func testToolCallDeltaDecoding() throws {
    let json = """
    {
        "index": 0,
        "id": "call_abc123",
        "type": "function",
        "function": {
            "name": "get_weather",
            "arguments": "{\\"loc"
        }
    }
    """
    let data = json.data(using: .utf8)!
    let delta = try JSONDecoder().decode(ToolCallDelta.self, from: data)

    #expect(delta.index == 0)
    #expect(delta.id == "call_abc123")
    #expect(delta.type == "function")
    #expect(delta.function?.name == "get_weather")
    #expect(delta.function?.arguments == "{\"loc")
}

@Test func testToolCallDeltaPartial() throws {
    let json = """
    {
        "index": 0,
        "function": {
            "arguments": "ation\\": \\"Paris\\"}"
        }
    }
    """
    let data = json.data(using: .utf8)!
    let delta = try JSONDecoder().decode(ToolCallDelta.self, from: data)

    #expect(delta.index == 0)
    #expect(delta.id == nil)
    #expect(delta.type == nil)
    #expect(delta.function?.name == nil)
    #expect(delta.function?.arguments == "ation\": \"Paris\"}")
}

// MARK: - ToolChoice Encoding Tests

@Test func testToolChoiceAutoEncoding() throws {
    let data = try JSONEncoder().encode(ToolChoice.auto)
    let str = String(data: data, encoding: .utf8)
    #expect(str == "\"auto\"")
}

@Test func testToolChoiceNoneEncoding() throws {
    let data = try JSONEncoder().encode(ToolChoice.none)
    let str = String(data: data, encoding: .utf8)
    #expect(str == "\"none\"")
}

@Test func testToolChoiceRequiredEncoding() throws {
    let data = try JSONEncoder().encode(ToolChoice.required)
    let str = String(data: data, encoding: .utf8)
    #expect(str == "\"required\"")
}

@Test func testToolChoiceFunctionEncoding() throws {
    let data = try JSONEncoder().encode(ToolChoice.function("get_weather"))
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["type"] as? String == "function")
    let function = json?["function"] as? [String: String]
    #expect(function?["name"] == "get_weather")
}

// MARK: - AssistantToolCallMessage Tests

@Test func testAssistantToolCallMessageEncoding() throws {
    let toolCall = ToolCall(
        id: "call_123",
        type: "function",
        function: ToolCall.FunctionCall(name: "get_weather", arguments: "{\"location\":\"Paris\"}")
    )
    let message = AssistantToolCallMessage(content: nil, toolCalls: [toolCall])

    let data = try JSONEncoder().encode(message)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["role"] as? String == "assistant")
    let toolCalls = json?["tool_calls"] as? [[String: Any]]
    #expect(toolCalls?.count == 1)
    #expect(toolCalls?[0]["id"] as? String == "call_123")
}

// MARK: - ToolResultMessage Tests

@Test func testToolResultMessageEncoding() throws {
    let message = ToolResultMessage(toolCallId: "call_123", content: "72°F, sunny")

    let data = try JSONEncoder().encode(message)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["role"] as? String == "tool")
    #expect(json?["tool_call_id"] as? String == "call_123")
    #expect(json?["content"] as? String == "72°F, sunny")
}

// MARK: - ChatResponse with Tool Calls Tests

@Test func testChatResponseWithToolCalls() throws {
    let jsonString = """
    {
        "id": "chatcmpl-tool",
        "object": "chat.completion",
        "created": 1700000000,
        "model": "gpt-4",
        "choices": [{
            "index": 0,
            "message": {
                "role": "assistant",
                "content": null,
                "tool_calls": [{
                    "id": "call_abc",
                    "type": "function",
                    "function": {
                        "name": "get_weather",
                        "arguments": "{\\"location\\":\\"Paris\\"}"
                    }
                }]
            },
            "finish_reason": "tool_calls"
        }],
        "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}
    }
    """

    let data = jsonString.data(using: .utf8)!
    let response = try JSONDecoder().decode(ChatResponse.self, from: data)

    // content decodes null as empty string
    #expect(response.choices[0].message.content == "")
    #expect(response.choices[0].message.toolCalls?.count == 1)
    #expect(response.choices[0].message.toolCalls?[0].id == "call_abc")
    #expect(response.choices[0].message.toolCalls?[0].function.name == "get_weather")
    #expect(response.firstFinishReason == "tool_calls")
    #expect(response.requiresToolExecution == true)
    #expect(response.firstToolCalls?.count == 1)
}

@Test func testChatResponseWithoutToolCalls() throws {
    let jsonString = """
    {
        "id": "chatcmpl-text",
        "object": "chat.completion",
        "created": 1700000000,
        "model": "gpt-4",
        "choices": [{
            "index": 0,
            "message": {
                "role": "assistant",
                "content": "Hello!"
            },
            "finish_reason": "stop"
        }],
        "usage": {"prompt_tokens": 5, "completion_tokens": 2, "total_tokens": 7}
    }
    """

    let data = jsonString.data(using: .utf8)!
    let response = try JSONDecoder().decode(ChatResponse.self, from: data)

    #expect(response.choices[0].message.content == "Hello!")
    #expect(response.choices[0].message.toolCalls == nil)
    #expect(response.requiresToolExecution == false)
    #expect(response.firstToolCalls == nil)
}

// MARK: - ChatDelta with Tool Calls Tests

@Test func testChatDeltaWithToolCalls() throws {
    let jsonString = """
    {
        "choices": [{
            "index": 0,
            "delta": {
                "role": "assistant",
                "tool_calls": [{
                    "index": 0,
                    "id": "call_abc",
                    "type": "function",
                    "function": {
                        "name": "get_weather",
                        "arguments": "{\\"loc"
                    }
                }]
            },
            "finish_reason": null
        }]
    }
    """

    let data = jsonString.data(using: .utf8)!
    let delta = try JSONDecoder().decode(ChatDelta.self, from: data)

    #expect(delta.firstToolCallDeltas?.count == 1)
    #expect(delta.firstToolCallDeltas?[0].id == "call_abc")
    #expect(delta.firstToolCallDeltas?[0].function?.name == "get_weather")
}

// MARK: - ChatRequest with ToolChoice Tests

@Test func testChatRequestToolChoiceEncoding() throws {
    var request = try ChatRequest(model: "gpt-4", messages: [
        TextMessage(role: .user, content: "Test"),
    ])
    request.toolChoice = .auto

    let data = try JSONEncoder().encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["tool_choice"] as? String == "auto")
}

@Test func testChatRequestToolChoiceOmittedWhenNil() throws {
    let request = try ChatRequest(model: "gpt-4", messages: [
        TextMessage(role: .user, content: "Test"),
    ])

    let data = try JSONEncoder().encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["tool_choice"] == nil)
}

// MARK: - Tool with JSONSchema Tests

@Test func testToolWithJSONSchema() throws {
    let tool = Tool(
        name: "search",
        description: "Search the web",
        parameters: .object(
            properties: [
                "query": .string(description: "Search query"),
                "limit": .integer(description: "Max results", minimum: 1, maximum: 100),
            ],
            required: ["query"]
        )
    )

    let data = try JSONEncoder().encode(tool)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    let function = json?["function"] as? [String: Any]
    let params = function?["parameters"] as? [String: Any]
    #expect(params?["type"] as? String == "object")

    let props = params?["properties"] as? [String: Any]
    let query = props?["query"] as? [String: Any]
    #expect(query?["type"] as? String == "string")
    #expect(query?["description"] as? String == "Search query")

    let limit = props?["limit"] as? [String: Any]
    #expect(limit?["type"] as? String == "integer")
    #expect(limit?["minimum"] as? Int == 1)
    #expect(limit?["maximum"] as? Int == 100)
}

// MARK: - New LLMError Cases Tests

@Test func testLLMErrorMaxIterationsExceeded() {
    let error = LLMError.maxIterationsExceeded(10)
    #expect(error == LLMError.maxIterationsExceeded(10))
    #expect(error != LLMError.maxIterationsExceeded(5))
}

@Test func testLLMErrorUnknownTool() {
    let error = LLMError.unknownTool("unknown_func")
    #expect(error == LLMError.unknownTool("unknown_func"))
    #expect(error != LLMError.unknownTool("other_func"))
}

@Test func testLLMErrorToolExecutionFailed() {
    let error = LLMError.toolExecutionFailed(toolName: "test", message: "failed")
    #expect(error == LLMError.toolExecutionFailed(toolName: "test", message: "failed"))
    #expect(error != LLMError.toolExecutionFailed(toolName: "test", message: "other"))
}

// MARK: - ChatConversation Tool Methods Tests

@Test func testChatConversationToolMethods() {
    var conversation = ChatConversation()
    conversation.addUser(content: "What's the weather?")

    let toolCall = ToolCall(
        id: "call_1",
        type: "function",
        function: ToolCall.FunctionCall(name: "get_weather", arguments: "{}")
    )
    conversation.addAssistantToolCalls(content: nil, toolCalls: [toolCall])
    conversation.addToolResult(toolCallId: "call_1", content: "72°F")

    #expect(conversation.messageCount == 3)
    #expect(conversation.lastMessageRole == .tool)
}

// MARK: - ToolChoiceParam Tests

@Test func testToolChoiceParamApply() throws {
    let request = try ChatRequest(model: "gpt-4", config: {
        ToolChoiceParam(.required)
    }, messages: [
        TextMessage(role: .user, content: "Test"),
    ])

    #expect(request.toolChoice == .required)
}

// MARK: - ChatRequest Tools Builder Tests

@Test func testChatRequestToolsBuilder() throws {
    let request = try ChatRequest(model: "gpt-4", toolChoice: .auto, config: {
        try Temperature(0.7)
    }, tools: {
        Tool(name: "get_weather", description: "Get weather",
             parameters: .object(properties: ["city": .string()], required: ["city"]))
        Tool(name: "calculate", description: "Calculate",
             parameters: .object(properties: ["expr": .string()], required: ["expr"]))
    }) {
        TextMessage(role: .user, content: "Hello")
    }

    #expect(request.tools?.count == 2)
    #expect(request.tools?[0].name == "get_weather")
    #expect(request.tools?[1].name == "calculate")
    #expect(request.toolChoice == .auto)
}

@Test func testChatRequestToolsBuilderWithArrayMessages() throws {
    let messages: [any ChatMessage] = [
        TextMessage(role: .user, content: "Hello"),
    ]

    let searchTool = Tool(
        name: "search",
        description: "Search",
        parameters: .object(properties: ["q": .string()], required: ["q"])
    )

    var request = try ChatRequest(model: "gpt-4", messages: messages)
    request.tools = [searchTool]
    request.toolChoice = .function("search")

    #expect(request.tools?.count == 1)
    #expect(request.toolChoice == .function("search"))
}

@Test func testChatRequestToolsBuilderEncoding() throws {
    let request = try ChatRequest(model: "gpt-4", toolChoice: .required, tools: {
        Tool(name: "test_tool", description: "A test tool",
             parameters: .object(properties: [:], required: []))
    }) {
        TextMessage(role: .user, content: "Test")
    }

    let data = try JSONEncoder().encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    let tools = json?["tools"] as? [[String: Any]]
    #expect(tools?.count == 1)
    let function = tools?[0]["function"] as? [String: Any]
    #expect(function?["name"] as? String == "test_tool")
    #expect(json?["tool_choice"] as? String == "required")
}

// MARK: - Convenience Message Tests

@Test func testSystemConvenienceFunction() {
    let msg = System("You are helpful.")
    #expect(msg.role == .system)
    #expect(msg.content == "You are helpful.")
}

@Test func testUserMessageConvenienceFunction() {
    let msg = UserMessage("Hello!")
    #expect(msg.role == .user)
    #expect(msg.content == "Hello!")
}

@Test func testConvenienceMessagesInChatBuilder() throws {
    let request = try ChatRequest(model: "gpt-4", config: {
        try Temperature(0.7)
    }) {
        System("You are a helpful assistant.")
        UserMessage("Explain Swift.")
    }

    #expect(request.messages.count == 2)
    #expect(request.messages[0].role == .system)
    #expect(request.messages[1].role == .user)
}

@Test func testBackwardCompatibilityOldChatRequest() throws {
    // Existing code patterns should still compile and work (array-based init)
    let request = try ChatRequest(model: "gpt-4", config: {
        try Temperature(0.7)
        try MaxTokens(150)
    }, messages: [
        TextMessage(role: .system, content: "System prompt"),
        TextMessage(role: .user, content: "User message"),
    ])

    #expect(request.model == "gpt-4")
    #expect(request.temperature == 0.7)
    #expect(request.maxTokens == 150)
    #expect(request.messages.count == 2)
    #expect(request.tools == nil)
    #expect(request.toolChoice == nil)
}

@Test func testBackwardCompatibilityArrayMessages() throws {
    let messages: [any ChatMessage] = [
        TextMessage(role: .system, content: "System"),
        TextMessage(role: .user, content: "User"),
    ]

    let request = try ChatRequest(
        model: "gpt-4",
        config: { try Temperature(0.5) },
        messages: messages
    )

    #expect(request.messages.count == 2)
    #expect(request.temperature == 0.5)
}

// MARK: - Assistant Convenience Tests

@Test func testAssistantConvenienceFunction() {
    let msg = Assistant("Hello there!")
    #expect(msg.role == .assistant)
    #expect(msg.content == "Hello there!")
}

@Test func testAssistantInChatBuilder() throws {
    let request = try ChatRequest(model: "gpt-4") {
        System("You are a helpful assistant.")
        UserMessage("What is 2+2?")
        Assistant("4")
        UserMessage("And 3+3?")
    }

    #expect(request.messages.count == 4)
    #expect(request.messages[0].role == .system)
    #expect(request.messages[1].role == .user)
    #expect(request.messages[2].role == .assistant)
    #expect(request.messages[3].role == .user)
}

// MARK: - User Convenience Tests

@Test func testUserConvenienceFunction() {
    let msg = User("Hello there!")
    #expect(msg.role == .user)
    #expect(msg.content == "Hello there!")
}

@Test func testUserInChatBuilder() throws {
    let request = try ChatRequest(model: "gpt-4") {
        System("You are a helpful assistant.")
        User("What is 2+2?")
        Assistant("4")
        User("And 3+3?")
    }

    #expect(request.messages.count == 4)
    #expect(request.messages[0].role == .system)
    #expect(request.messages[1].role == .user)
    #expect(request.messages[2].role == .assistant)
    #expect(request.messages[3].role == .user)
}

@Test func testUserIDConfigParameter() throws {
    // Verify UserID (formerly User) still works as config parameter
    let request = try ChatRequest(model: "gpt-4", config: {
        try UserID("user-abc123")
    }) {
        User("Hello")
    }

    #expect(request.user == "user-abc123")
    #expect(request.messages.count == 1)
    #expect(request.messages[0].role == .user)
}

// MARK: - SessionBuilder Tests

@Test func testSessionBuilderMessages() {
    @SessionBuilder func build() -> [SessionComponent] {
        System("You are helpful.")
        User("Hello!")
    }

    let components = build()
    #expect(components.count == 2)
    if case .message(let msg) = components[0] {
        #expect(msg.role == .system)
    } else {
        #expect(Bool(false), "Expected .message")
    }
    if case .message(let msg) = components[1] {
        #expect(msg.role == .user)
    } else {
        #expect(Bool(false), "Expected .message")
    }
}

@Test func testSessionBuilderMixed() {
    let tool = Tool(name: "test_tool", description: "A test tool",
                    parameters: .object(properties: [:], required: []))

    @SessionBuilder func build() -> [SessionComponent] {
        System("You are helpful.")
        AgentTool(tool: tool) { _ in "result" }
    }

    let components = build()
    #expect(components.count == 2)
    if case .message = components[0] { } else {
        #expect(Bool(false), "Expected .message")
    }
    if case .agentTool(let at) = components[1] {
        #expect(at.tool.name == "test_tool")
    } else {
        #expect(Bool(false), "Expected .agentTool")
    }
}

// MARK: - ToolCall.decodeArguments Tests

@Test func testDecodeArgumentsSuccess() throws {
    struct WeatherArgs: Decodable {
        let location: String
        let unit: String
    }

    let toolCall = ToolCall(
        id: "call_1",
        function: ToolCall.FunctionCall(
            name: "get_weather",
            arguments: "{\"location\":\"Paris\",\"unit\":\"celsius\"}"
        )
    )

    let args: WeatherArgs = try toolCall.decodeArguments()
    #expect(args.location == "Paris")
    #expect(args.unit == "celsius")
}

@Test func testDecodeArgumentsInvalidJSON() {
    let toolCall = ToolCall(
        id: "call_1",
        function: ToolCall.FunctionCall(
            name: "test",
            arguments: "not valid json"
        )
    )

    #expect(throws: LLMError.self) {
        try toolCall.decodeArguments([String: String].self)
    }
}

// MARK: - ToolCallAccumulator Tests

@Test func testToolCallAccumulatorBasic() {
    var accumulator = ToolCallAccumulator()

    // First chunk: id, name, start of arguments
    accumulator.append(ToolCallDelta(
        index: 0,
        id: "call_1",
        type: "function",
        function: ToolCallDelta.FunctionCallDelta(name: "get_weather", arguments: "{\"loc")
    ))

    // Second chunk: more arguments
    accumulator.append(ToolCallDelta(
        index: 0,
        function: ToolCallDelta.FunctionCallDelta(arguments: "ation\":\"Paris\"}")
    ))

    let toolCalls = accumulator.toolCalls
    #expect(toolCalls.count == 1)
    #expect(toolCalls[0].id == "call_1")
    #expect(toolCalls[0].type == "function")
    #expect(toolCalls[0].function.name == "get_weather")
    #expect(toolCalls[0].function.arguments == "{\"location\":\"Paris\"}")
}

@Test func testToolCallAccumulatorParallel() {
    var accumulator = ToolCallAccumulator()

    // Two tool calls arriving interleaved
    accumulator.append(ToolCallDelta(
        index: 0,
        id: "call_1",
        type: "function",
        function: ToolCallDelta.FunctionCallDelta(name: "get_weather", arguments: "{}")
    ))
    accumulator.append(ToolCallDelta(
        index: 1,
        id: "call_2",
        type: "function",
        function: ToolCallDelta.FunctionCallDelta(name: "get_time", arguments: "{}")
    ))

    let toolCalls = accumulator.toolCalls
    #expect(toolCalls.count == 2)
    #expect(toolCalls[0].function.name == "get_weather")
    #expect(toolCalls[1].function.name == "get_time")
}

@Test func testToolCallAccumulatorReset() {
    var accumulator = ToolCallAccumulator()

    accumulator.append(ToolCallDelta(
        index: 0,
        id: "call_1",
        type: "function",
        function: ToolCallDelta.FunctionCallDelta(name: "test", arguments: "{}")
    ))

    #expect(accumulator.toolCalls.count == 1)

    accumulator.reset()

    #expect(accumulator.toolCalls.isEmpty)
}

// MARK: - JSONSchema.null Tests

@Test func testJSONSchemaNullEncoding() throws {
    let schema = JSONSchema.null
    let data = try JSONEncoder().encode(schema)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(json?["type"] as? String == "null")
}

// MARK: - Agent Introspection Tests

@Test func testAgentToolIntrospection() async throws {
    let config = URLSessionConfiguration.ephemeral
    let client = try LLMClient(
        baseURL: "https://api.test.com/chat",
        apiKey: "test-key",
        sessionConfiguration: config
    )

    let tool1 = Tool(name: "tool_a", description: "Tool A",
                     parameters: .object(properties: [:], required: []))
    let tool2 = Tool(name: "tool_b", description: "Tool B",
                     parameters: .object(properties: [:], required: []))

    let agent = try Agent(
        client: client,
        model: "gpt-4",
        tools: [tool1, tool2],
        toolHandlers: ["tool_a": { _ in "a" }, "tool_b": { _ in "b" }]
    )

    let names = await agent.registeredToolNames
    #expect(names == ["tool_a", "tool_b"])
    let count = await agent.toolCount
    #expect(count == 2)
}

// MARK: - Agent Builder Duplicate Tool Detection

@Test func testAgentBuilderDuplicateToolThrows() throws {
    let config = URLSessionConfiguration.ephemeral
    let client = try LLMClient(
        baseURL: "https://api.test.com/chat",
        apiKey: "test-key",
        sessionConfiguration: config
    )

    let tool = Tool(name: "duplicate_tool", description: "Test",
                    parameters: .object(properties: [:], required: []))

    #expect(throws: LLMError.self) {
        _ = try Agent(client: client, model: "gpt-4") {
            AgentTool(tool: tool) { _ in "result1" }
            AgentTool(tool: tool) { _ in "result2" }
        }
    }
}

// MARK: - Agent Builder No Tools

@Test func testAgentBuilderNoTools() throws {
    let config = URLSessionConfiguration.ephemeral
    let client = try LLMClient(
        baseURL: "https://api.test.com/chat",
        apiKey: "test-key",
        sessionConfiguration: config
    )

    let agent = try Agent(client: client, model: "gpt-4")
    // Verify we can check tool count without errors
    // (this is synchronous creation, no network calls)
    _ = agent
}

// MARK: - ToolSession Integration Tests

struct ToolSessionTests {

    @Test func toolSessionSingleToolCall() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        // First response: tool call
        let toolCallResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {
                            "name": "get_weather",
                            "arguments": "{\\"location\\":\\"Paris\\"}"
                        }
                    }]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}
        }
        """

        // Second response: final text
        let textResponse = """
        {
            "id": "chatcmpl-2",
            "object": "chat.completion",
            "created": 1700000001,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "The weather in Paris is 72°F and sunny."
                },
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 20, "completion_tokens": 10, "total_tokens": 30}
        }
        """

        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let body = callCount == 1 ? toolCallResponse : textResponse
            return (response, body.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let tool = Tool(
            name: "get_weather",
            description: "Get weather",
            parameters: .object(
                properties: ["location": .string(description: "City")],
                required: ["location"]
            )
        )

        let session = try ToolSession(
            client: client,
            tools: [tool],
            handlers: ["get_weather": { _ in
                return "{\"temperature\": 72, \"condition\": \"sunny\"}"
            }]
        )

        let result = try await session.run(
            model: "gpt-4",
            messages: [TextMessage(role: .user, content: "Weather in Paris?")]
        )

        #expect(result.response.firstContent == "The weather in Paris is 72°F and sunny.")
        #expect(result.iterations == 1)
        #expect(result.log.count == 1)
        #expect(result.log[0].name == "get_weather")
        #expect(callCount == 2)
    }

    @Test func toolSessionParallelToolCalls() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let toolCallResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [
                        {
                            "id": "call_1",
                            "type": "function",
                            "function": {"name": "get_weather", "arguments": "{\\"location\\":\\"Paris\\"}"}
                        },
                        {
                            "id": "call_2",
                            "type": "function",
                            "function": {"name": "get_weather", "arguments": "{\\"location\\":\\"London\\"}"}
                        }
                    ]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}
        }
        """

        let textResponse = """
        {
            "id": "chatcmpl-2",
            "object": "chat.completion",
            "created": 1700000001,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "Both cities are sunny."},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 30, "completion_tokens": 5, "total_tokens": 35}
        }
        """

        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            let body = callCount == 1 ? toolCallResponse : textResponse
            return (response, body.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let tool = Tool(
            name: "get_weather",
            description: "Get weather",
            parameters: .object(properties: ["location": .string()], required: ["location"])
        )

        let session = try ToolSession(
            client: client,
            tools: [tool],
            handlers: ["get_weather": { args in
                return "{\"temp\": 72}"
            }]
        )

        let result = try await session.run(
            model: "gpt-4",
            messages: [TextMessage(role: .user, content: "Weather in Paris and London?")]
        )

        #expect(result.log.count == 2)
        #expect(result.iterations == 1)
    }

    @Test func toolSessionMaxIterationsExceeded() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        // Always return tool calls — never a final response
        let toolCallResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {"name": "loop_tool", "arguments": "{}"}
                    }]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {"prompt_tokens": 5, "completion_tokens": 5, "total_tokens": 10}
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, toolCallResponse.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let tool = Tool(name: "loop_tool", description: "Always loops",
                        parameters: .object(properties: [:], required: []))

        let session = ToolSession(
            client: client,
            tools: [tool],
            maxIterations: 2,
            handlers: ["loop_tool": { _ in "result" }]
        )

        await #expect(throws: LLMError.self) {
            try await session.run(
                model: "gpt-4",
                messages: [TextMessage(role: .user, content: "Loop")]
            )
        }
    }

    @Test func toolSessionUnknownTool() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let toolCallResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {"name": "unknown_func", "arguments": "{}"}
                    }]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {"prompt_tokens": 5, "completion_tokens": 5, "total_tokens": 10}
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, toolCallResponse.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let tool = Tool(name: "known_tool", description: "Known",
                        parameters: .object(properties: [:], required: []))

        let session = try ToolSession(
            client: client,
            tools: [tool],
            handlers: ["known_tool": { _ in "ok" }]
        )

        do {
            _ = try await session.run(
                model: "gpt-4",
                messages: [TextMessage(role: .user, content: "Test")]
            )
            #expect(Bool(false), "Should have thrown unknownTool")
        } catch LLMError.unknownTool(let name) {
            #expect(name == "unknown_func")
        } catch {
            #expect(Bool(false), "Wrong error: \(error)")
        }
    }

    @Test func toolSessionHandlerThrows() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let toolCallResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {"name": "failing_tool", "arguments": "{}"}
                    }]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {"prompt_tokens": 5, "completion_tokens": 5, "total_tokens": 10}
        }
        """

        // Second response: model acknowledges the tool error and produces a final text response
        let textResponse = """
        {
            "id": "chatcmpl-2",
            "object": "chat.completion",
            "created": 1700000001,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "I couldn't execute the tool due to an error."},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 20, "completion_tokens": 5, "total_tokens": 25}
        }
        """

        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            let body = callCount == 1 ? toolCallResponse : textResponse
            return (response, body.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let tool = Tool(name: "failing_tool", description: "Always fails",
                        parameters: .object(properties: [:], required: []))

        struct ToolError: Error, LocalizedError {
            var errorDescription: String? { "Something went wrong" }
        }

        let session = ToolSession(
            client: client,
            tools: [tool],
            handlers: ["failing_tool": { _ in throw ToolError() }]
        )

        // Handler errors are wrapped in toolExecutionFailed and thrown
        await #expect(throws: LLMError.self) {
            try await session.run(
                model: "gpt-4",
                messages: [TextMessage(role: .user, content: "Test")]
            )
        }
    }

    @Test func toolSessionMaxIterationsOne() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let toolCallResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {"name": "loop_tool", "arguments": "{}"}
                    }]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {"prompt_tokens": 5, "completion_tokens": 5, "total_tokens": 10}
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, toolCallResponse.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let tool = Tool(name: "loop_tool", description: "Always loops",
                        parameters: .object(properties: [:], required: []))

        let session = ToolSession(
            client: client,
            tools: [tool],
            maxIterations: 1,
            handlers: ["loop_tool": { _ in "result" }]
        )

        await #expect(throws: LLMError.self) {
            try await session.run(
                model: "gpt-4",
                messages: [TextMessage(role: .user, content: "Loop")]
            )
        }
    }
}

// MARK: - Agent Tests

struct AgentTests {

    @Test func agentMultiTurnWithToolCalls() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let toolCallResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {"name": "add", "arguments": "{\\"a\\": 2, \\"b\\": 3}"}
                    }]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}
        }
        """

        let textResponse = """
        {
            "id": "chatcmpl-2",
            "object": "chat.completion",
            "created": 1700000001,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "2 + 3 = 5"},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 20, "completion_tokens": 5, "total_tokens": 25}
        }
        """

        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            let body = callCount == 1 ? toolCallResponse : textResponse
            return (response, body.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let addTool = Tool(
            name: "add",
            description: "Add two numbers",
            parameters: .object(
                properties: ["a": .integer(), "b": .integer()],
                required: ["a", "b"]
            )
        )

        let agent = try Agent(
            client: client,
            model: "gpt-4",
            systemPrompt: "You are a calculator.",
            tools: [addTool],
            toolHandlers: ["add": { args in "5" }]
        )

        let response = try await agent.send("What is 2 + 3?")
        #expect(response == "2 + 3 = 5")

        let history = await agent.history
        #expect(history.count >= 2) // system + user + tool messages + assistant
    }

    @Test func agentTranscriptLogging() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let textResponse = """
        {
            "id": "chatcmpl-1",
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
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, textResponse.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let agent = try Agent(client: client, model: "gpt-4")

        _ = try await agent.send("Hi")

        let transcript = await agent.transcript
        #expect(transcript.count == 2)
        if case .userMessage(let msg) = transcript[0] {
            #expect(msg == "Hi")
        } else {
            #expect(Bool(false), "Expected userMessage")
        }
        if case .assistantMessage(let msg) = transcript[1] {
            #expect(msg == "Hello!")
        } else {
            #expect(Bool(false), "Expected assistantMessage")
        }
    }

    @Test func agentReset() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let textResponse = """
        {
            "id": "chatcmpl-1",
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
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, textResponse.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let agent = try Agent(client: client, model: "gpt-4")

        _ = try await agent.send("Hi")
        let historyBefore = await agent.history
        #expect(!historyBefore.isEmpty)

        await agent.reset()

        let historyAfter = await agent.history
        #expect(historyAfter.isEmpty)
        let transcriptAfter = await agent.transcript
        #expect(transcriptAfter.isEmpty)
    }

    @Test func agentSendWithoutTools() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let textResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "Hello! How can I help?"},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 5, "completion_tokens": 5, "total_tokens": 10}
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, textResponse.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let agent = try Agent(client: client, model: "gpt-4", systemPrompt: "You are helpful.")

        let response = try await agent.send("Hi there")
        #expect(response == "Hello! How can I help?")

        let history = await agent.history
        // system + user + assistant = 3
        #expect(history.count == 3)
        #expect(history[0].role == .system)
        #expect(history[1].role == .user)
        #expect(history[2].role == .assistant)

        let toolCount = await agent.toolCount
        #expect(toolCount == 0)
    }
} // end AgentTests

// MARK: - Declarative Init Tests

struct DeclarativeInitTests {

    @Test func toolSessionDeclarativeInit() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        // First response: tool call
        let toolCallResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {
                            "name": "get_weather",
                            "arguments": "{\\"location\\":\\"Paris\\"}"
                        }
                    }]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}
        }
        """

        // Second response: final text
        let textResponse = """
        {
            "id": "chatcmpl-2",
            "object": "chat.completion",
            "created": 1700000001,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "The weather in Paris is 72°F and sunny."
                },
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 20, "completion_tokens": 10, "total_tokens": 30}
        }
        """

        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let body = callCount == 1 ? toolCallResponse : textResponse
            return (response, body.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let weatherTool = Tool(
            name: "get_weather",
            description: "Get weather",
            parameters: .object(
                properties: ["location": .string(description: "City")],
                required: ["location"]
            )
        )

        let session = try ToolSession(client: client, model: "gpt-4") {
            System("You are a weather assistant.")
            AgentTool(tool: weatherTool) { _ in
                return "{\"temperature\": 72, \"condition\": \"sunny\"}"
            }
        }

        let result = try await session.run("What's the weather in Paris?")

        #expect(result.response.firstContent == "The weather in Paris is 72°F and sunny.")
        #expect(result.iterations == 1)
        #expect(result.log.count == 1)
        #expect(result.log[0].name == "get_weather")
        #expect(callCount == 2)
    }

    @Test func agentDeclarativeInitAndRun() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let textResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "Hello! I'm a helpful assistant."},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 5, "completion_tokens": 5, "total_tokens": 10}
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, textResponse.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let agent = try Agent(client: client, model: "gpt-4") {
            System("You are a helpful assistant.")
        }

        let response = try await agent.send("Hi there")
        #expect(response == "Hello! I'm a helpful assistant.")

        let history = await agent.history
        // system + user + assistant = 3
        #expect(history.count == 3)
        #expect(history[0].role == .system)
        #expect(history[1].role == .user)
        #expect(history[2].role == .assistant)
    }

    @Test func agentDeclarativeInitWithTools() async throws {
        let config = URLSessionConfiguration.ephemeral
        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let tool = Tool(name: "calc", description: "Calculate",
                        parameters: .object(properties: [:], required: []))

        let agent = try Agent(client: client, model: "gpt-4") {
            System("You are a calculator.")
            AgentTool(tool: tool) { _ in "42" }
        }

        let names = await agent.registeredToolNames
        #expect(names == ["calc"])
        let count = await agent.toolCount
        #expect(count == 1)
    }

} // end DeclarativeInitTests

// MARK: - New Feature Tests (Robustness Improvements)

// MARK: Validation Gaps

@Test func testLogitBiasApplies() throws {
    let bias = LogitBias(["token": 100, "other": -100, "mid": 0])
    var request = try ChatRequest(model: "gpt-4", messages: [
        TextMessage(role: .user, content: "hi")
    ])
    bias.apply(to: &request)
    #expect(request.logitBias?["token"] == 100)
}

@Test func testStopEmptyArrayThrows() {
    #expect(throws: LLMError.self) {
        try Stop([])
    }
}

@Test func testStopSequencesApplies() throws {
    let stop = try Stop(["a", "b", "c", "d"])
    var request = try ChatRequest(model: "gpt-4", messages: [
        TextMessage(role: .user, content: "hi")
    ])
    stop.apply(to: &request)
    #expect(request.stop?.count == 4)
}

@Test func testNZeroThrows() {
    #expect(throws: LLMError.self) {
        try N(0)
    }
}

@Test func testNPositiveValueSucceeds() throws {
    let n = try N(128)
    var request = try ChatRequest(model: "gpt-4", messages: [
        TextMessage(role: .user, content: "hi")
    ])
    n.apply(to: &request)
    #expect(request.n == 128)
}

// MARK: Content Optional

@Test func testChatResponseContentNullDecodesAsNil() throws {
    let json = """
    {
        "id": "chatcmpl-1",
        "object": "chat.completion",
        "created": 1700000000,
        "model": "gpt-4",
        "choices": [{
            "index": 0,
            "message": {
                "role": "assistant",
                "content": null,
                "tool_calls": [{
                    "id": "call_1",
                    "type": "function",
                    "function": {"name": "get_weather", "arguments": "{}"}
                }]
            },
            "finish_reason": "tool_calls"
        }],
        "usage": {"prompt_tokens": 5, "completion_tokens": 5, "total_tokens": 10}
    }
    """
    let response = try JSONDecoder().decode(ChatResponse.self, from: json.data(using: .utf8)!)
    #expect(response.choices[0].message.content == "")
    #expect(response.firstContent == "")
}

@Test func testChatResponseContentEmptyStringDecodesCorrectly() throws {
    let json = """
    {
        "id": "chatcmpl-1",
        "object": "chat.completion",
        "created": 1700000000,
        "model": "gpt-4",
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": ""},
            "finish_reason": "stop"
        }],
        "usage": {"prompt_tokens": 5, "completion_tokens": 0, "total_tokens": 5}
    }
    """
    let response = try JSONDecoder().decode(ChatResponse.self, from: json.data(using: .utf8)!)
    #expect(response.choices[0].message.content == "")
    #expect(response.firstContent == "")
}

// MARK: totalTokens When No Usage

@Test func testTotalTokensZeroWhenNoUsage() throws {
    let json = """
    {
        "id": "chatcmpl-1",
        "object": "chat.completion",
        "created": 1700000000,
        "model": "gpt-4",
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": "Hello"},
            "finish_reason": "stop"
        }]
    }
    """
    let response = try JSONDecoder().decode(ChatResponse.self, from: json.data(using: .utf8)!)
    #expect(response.usage == nil)
    #expect(response.totalTokens == 0)
}

@Test func testTotalTokensPresentWhenUsageIncluded() throws {
    let json = """
    {
        "id": "chatcmpl-1",
        "object": "chat.completion",
        "created": 1700000000,
        "model": "gpt-4",
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": "Hello"},
            "finish_reason": "stop"
        }],
        "usage": {"prompt_tokens": 5, "completion_tokens": 3, "total_tokens": 8}
    }
    """
    let response = try JSONDecoder().decode(ChatResponse.self, from: json.data(using: .utf8)!)
    #expect(response.totalTokens == 8)
}

// MARK: Convenience Tool Message Functions

@Test func testAssistantToolCallMessageConvenience() {
    let toolCall = ToolCall(
        id: "call_1",
        function: ToolCall.FunctionCall(name: "get_weather", arguments: "{}")
    )
    let msg = AssistantToolCallMessage(content: nil, toolCalls: [toolCall])
    #expect(msg.role == .assistant)
    #expect(msg.toolCalls.count == 1)
    #expect(msg.toolCalls[0].id == "call_1")
    #expect(msg.content == nil)
}

@Test func testToolResultMessageConvenience() {
    let msg = ToolResultMessage(toolCallId: "call_1", content: "{\"temperature\": 72}")
    #expect(msg.role == .tool)
    #expect(msg.toolCallId == "call_1")
    #expect(msg.content == "{\"temperature\": 72}")
}

// MARK: Duplicate Detection Throws (Explicit Inits)

// Note: ToolSession and Agent explicit inits use precondition for duplicate tool names,
// which cannot be tested with #expect(throws:). The Agent builder init uses throws
// for duplicates — see testAgentBuilderDuplicateToolThrows.

// MARK: ChatRequest Tools+Messages Builder Init

@Test func testChatRequestToolsAndMessagesBuilder() throws {
    let request = try ChatRequest(model: "gpt-4", toolChoice: .auto, tools: {
        Tool(name: "get_weather", description: "Get weather info",
             parameters: .object(properties: ["city": .string()], required: ["city"]))
    }) {
        TextMessage(role: .user, content: "What's the weather?")
    }

    #expect(request.messages.count == 1)
    #expect(request.messages[0].role == .user)
    #expect(request.tools?.count == 1)
    #expect(request.tools?[0].name == "get_weather")
    #expect(request.toolChoice == .auto)
}

@Test func testChatRequestMessagesBuilderOnly() throws {
    let request = try ChatRequest(model: "gpt-4") {
        System("You are helpful.")
        User("Hello!")
    }

    #expect(request.messages.count == 2)
    #expect(request.messages[0].role == .system)
    #expect(request.messages[1].role == .user)
    #expect(request.tools == nil)
}

// MARK: - ToolSession Stream Tests

    @Test func toolSessionStreamBasic() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let toolCallResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "Let me check the weather.",
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {"name": "get_weather", "arguments": "{\\"city\\":\\"Paris\\"}"}
                    }]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}
        }
        """

        let textResponse = """
        {
            "id": "chatcmpl-2",
            "object": "chat.completion",
            "created": 1700000001,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "It's sunny in Paris."},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 20, "completion_tokens": 5, "total_tokens": 25}
        }
        """

        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            let body = callCount == 1 ? toolCallResponse : textResponse
            return (response, body.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let tool = Tool(
            name: "get_weather",
            description: "Get weather",
            parameters: .object(
                properties: ["city": .string(description: "City")],
                required: ["city"]
            )
        )

        let session = ToolSession(
            client: client,
            tools: [tool],
            handlers: ["get_weather": { _ in "{\"temp\": 72}" }]
        )

        let stream = session.stream(
            model: "gpt-4",
            messages: [TextMessage(role: .user, content: "Weather in Paris?")],
            configParams: []
        )

        var events: [String] = []
        for try await event in stream {
            switch event {
            case .modelResponse(let content, let toolCalls, let iteration):
                events.append("modelResponse")
                #expect(content == "Let me check the weather.")
                #expect(toolCalls.count == 1)
                #expect(iteration == 0)
            case .toolStarted(let name, _):
                events.append("toolStarted:\(name)")
            case .toolCompleted(let name, _, _):
                events.append("toolCompleted:\(name)")
            case .completed(let result):
                events.append("completed")
                #expect(result.response.firstContent == "It's sunny in Paris.")
                #expect(result.iterations == 1)
                #expect(result.log.count == 1)
            }
        }

        #expect(events == [
            "modelResponse",
            "toolStarted:get_weather",
            "toolCompleted:get_weather",
            "completed",
        ])
    }

    @Test func toolSessionStreamNoToolsNeeded() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let textResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "Hello there!"},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 5, "completion_tokens": 3, "total_tokens": 8}
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, textResponse.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let tool = Tool(
            name: "get_weather",
            description: "Get weather",
            parameters: .object(properties: [:], required: [])
        )

        let session = ToolSession(
            client: client,
            tools: [tool],
            handlers: ["get_weather": { _ in "result" }]
        )

        let stream = session.stream(
            model: "gpt-4",
            messages: [TextMessage(role: .user, content: "Hi")],
            configParams: []
        )

        var events: [String] = []
        for try await event in stream {
            switch event {
            case .completed(let result):
                events.append("completed")
                #expect(result.response.firstContent == "Hello there!")
                #expect(result.iterations == 0)
            default:
                events.append("unexpected")
            }
        }

        #expect(events == ["completed"])
    }

    @Test func toolSessionStreamMultipleIterations() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let toolCallResponse1 = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {"name": "step", "arguments": "{\\"n\\": 1}"}
                    }]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {"prompt_tokens": 5, "completion_tokens": 5, "total_tokens": 10}
        }
        """

        let toolCallResponse2 = """
        {
            "id": "chatcmpl-2",
            "object": "chat.completion",
            "created": 1700000001,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_2",
                        "type": "function",
                        "function": {"name": "step", "arguments": "{\\"n\\": 2}"}
                    }]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}
        }
        """

        let textResponse = """
        {
            "id": "chatcmpl-3",
            "object": "chat.completion",
            "created": 1700000002,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "Done after 2 steps."},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 15, "completion_tokens": 5, "total_tokens": 20}
        }
        """

        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            let body: String
            switch callCount {
            case 1: body = toolCallResponse1
            case 2: body = toolCallResponse2
            default: body = textResponse
            }
            return (response, body.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let tool = Tool(
            name: "step",
            description: "A step",
            parameters: .object(properties: ["n": .integer()], required: ["n"])
        )

        let session = ToolSession(
            client: client,
            tools: [tool],
            handlers: ["step": { args in "done:\(args)" }]
        )

        let stream = session.stream(
            model: "gpt-4",
            messages: [TextMessage(role: .user, content: "Go")],
            configParams: []
        )

        var events: [String] = []
        for try await event in stream {
            switch event {
            case .modelResponse(_, _, let iteration):
                events.append("modelResponse:\(iteration)")
            case .toolStarted(let name, _):
                events.append("toolStarted:\(name)")
            case .toolCompleted(let name, _, _):
                events.append("toolCompleted:\(name)")
            case .completed(let result):
                events.append("completed")
                #expect(result.iterations == 2)
                #expect(result.log.count == 2)
            }
        }

        #expect(events == [
            "modelResponse:0",
            "toolStarted:step",
            "toolCompleted:step",
            "modelResponse:1",
            "toolStarted:step",
            "toolCompleted:step",
            "completed",
        ])
    }

    @Test func toolSessionStreamErrorPropagation() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let toolCallResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {"name": "fail_tool", "arguments": "{}"}
                    }]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {"prompt_tokens": 5, "completion_tokens": 5, "total_tokens": 10}
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, toolCallResponse.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let tool = Tool(
            name: "fail_tool",
            description: "Always fails",
            parameters: .object(properties: [:], required: [])
        )

        struct ToolError: Error {}

        let session = ToolSession(
            client: client,
            tools: [tool],
            handlers: ["fail_tool": { _ in throw ToolError() }]
        )

        let stream = session.stream(
            model: "gpt-4",
            messages: [TextMessage(role: .user, content: "Go")],
            configParams: []
        )

        var gotModelResponse = false
        await #expect(throws: LLMError.self) {
            for try await event in stream {
                if case .modelResponse = event {
                    gotModelResponse = true
                }
            }
        }
        #expect(gotModelResponse)
    }

    @Test func toolSessionStreamMaxIterations() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let toolCallResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {"name": "loop_tool", "arguments": "{}"}
                    }]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {"prompt_tokens": 5, "completion_tokens": 5, "total_tokens": 10}
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, toolCallResponse.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let tool = Tool(
            name: "loop_tool",
            description: "Always loops",
            parameters: .object(properties: [:], required: [])
        )

        let session = ToolSession(
            client: client,
            tools: [tool],
            maxIterations: 2,
            handlers: ["loop_tool": { _ in "ok" }]
        )

        let stream = session.stream(
            model: "gpt-4",
            messages: [TextMessage(role: .user, content: "Loop")],
            configParams: []
        )

        var eventCount = 0
        await #expect(throws: LLMError.self) {
            for try await _ in stream {
                eventCount += 1
            }
        }
        // 2 iterations × (modelResponse + toolStarted + toolCompleted) = 6
        #expect(eventCount == 6)
    }

    @Test func toolSessionStreamDeclarativeShorthand() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let textResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "Hi!"},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 5, "completion_tokens": 2, "total_tokens": 7}
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, textResponse.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let tool = Tool(
            name: "greet",
            description: "Greet",
            parameters: .object(properties: [:], required: [])
        )

        let session = ToolSession(client: client, model: "gpt-4") {
            System("You are helpful.")
            AgentTool(tool: tool) { _ in "hello" }
        }

        let stream = session.stream("Say hi")

        var events: [String] = []
        for try await event in stream {
            if case .completed(let result) = event {
                events.append("completed")
                #expect(result.response.firstContent == "Hi!")
            }
        }

        #expect(events == ["completed"])
    }

    // MARK: - Agent Stream Tests

    @Test func agentStreamSendBasic() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let toolCallResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {"name": "add", "arguments": "{\\"a\\": 2, \\"b\\": 3}"}
                    }]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}
        }
        """

        let textResponse = """
        {
            "id": "chatcmpl-2",
            "object": "chat.completion",
            "created": 1700000001,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "2 + 3 = 5"},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 20, "completion_tokens": 5, "total_tokens": 25}
        }
        """

        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            let body = callCount == 1 ? toolCallResponse : textResponse
            return (response, body.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let tool = Tool(
            name: "add",
            description: "Add numbers",
            parameters: .object(
                properties: ["a": .integer(), "b": .integer()],
                required: ["a", "b"]
            )
        )

        let agent = try Agent(
            client: client,
            model: "gpt-4",
            systemPrompt: "You are a calculator."
        ) {
            AgentTool(tool: tool) { _ in "5" }
        }

        let stream = await agent.streamSend("Add 2 + 3")

        var events: [String] = []
        for try await event in stream {
            switch event {
            case .modelResponse: events.append("modelResponse")
            case .toolStarted: events.append("toolStarted")
            case .toolCompleted: events.append("toolCompleted")
            case .completed(let result):
                events.append("completed")
                #expect(result.response.firstContent == "2 + 3 = 5")
            }
        }

        #expect(events == [
            "modelResponse",
            "toolStarted",
            "toolCompleted",
            "completed",
        ])

        // Verify history and transcript updated
        let history = await agent.history
        #expect(history.count > 2) // system + user + tool calls + assistant
        let transcript = await agent.transcript
        #expect(transcript.contains { if case .userMessage = $0 { return true }; return false })
        #expect(transcript.contains { if case .assistantMessage = $0 { return true }; return false })
    }

    @Test func agentStreamSendNoTools() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let textResponse = """
        {
            "id": "chatcmpl-1",
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
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, textResponse.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let agent = Agent(
            client: client,
            model: "gpt-4",
            systemPrompt: "You are helpful."
        )

        let stream = await agent.streamSend("Hi")

        var events: [String] = []
        for try await event in stream {
            if case .completed(let result) = event {
                events.append("completed")
                #expect(result.response.firstContent == "Hello!")
            } else {
                events.append("unexpected")
            }
        }

        #expect(events == ["completed"])

        let history = await agent.history
        #expect(history.count == 3) // system + user + assistant
    }

    @Test func agentStreamRunAlias() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let textResponse = """
        {
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "Hi!"},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 5, "completion_tokens": 2, "total_tokens": 7}
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, textResponse.data(using: .utf8)!)
        }

        let client = try LLMClient(
            baseURL: "https://api.test.com/chat",
            apiKey: "test-key",
            sessionConfiguration: config
        )

        let agent = Agent(client: client, model: "gpt-4")

        let stream = await agent.streamRun("Hello")

        var gotCompleted = false
        for try await event in stream {
            if case .completed = event {
                gotCompleted = true
            }
        }
        #expect(gotCompleted)
    }

} // end AllNetworkTests
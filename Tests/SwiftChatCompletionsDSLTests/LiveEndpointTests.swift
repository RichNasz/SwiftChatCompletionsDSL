//
//  LiveEndpointTests.swift
//  SwiftChatCompletionsDSL
//
//  Created by Richard Naszcyniec on 3/18/26.
//  Code assisted by AI
//

import Foundation
import Testing
@testable import SwiftChatCompletionsDSL

// MARK: - Live Endpoint Configuration

private enum LiveConfig {
    static let isEnabled = ProcessInfo.processInfo.environment["LIVE_TEST"] == "1"

    static var endpointURL: String {
        let raw = ProcessInfo.processInfo.environment["LIVE_ENDPOINT_URL"] ?? "http://127.0.0.1:1234"
        if let url = URL(string: raw),
           url.path.isEmpty || url.path == "/" {
            return raw.hasSuffix("/")
                ? raw + "v1/chat/completions"
                : raw + "/v1/chat/completions"
        }
        return raw
    }

    static var model: String {
        ProcessInfo.processInfo.environment["LIVE_ENDPOINT_MODEL"] ?? "nvidia/nemotron-3-nano"
    }

    static var apiKey: String {
        ProcessInfo.processInfo.environment["LIVE_ENDPOINT_API_KEY"] ?? ""
    }
}

// MARK: - Live Endpoint Tests

@Suite(.serialized)
struct LiveEndpointTests {

    // MARK: - Basic Non-Streaming Completion

    @Test(.enabled(if: LiveConfig.isEnabled))
    func basicCompletion() async throws {
        let client = try LLMClient(baseURL: LiveConfig.endpointURL, apiKey: LiveConfig.apiKey)

        let request = try ChatRequest(model: LiveConfig.model, config: {
            try RequestTimeout(120)
            try ResourceTimeout(180)
        }, messages: [
            TextMessage(role: .user, content: "Say hello in exactly one word."),
        ])

        let response = try await client.complete(request)
        let content = response.firstContent ?? ""
        #expect(!content.isEmpty, "Expected non-empty response content")
        #expect(response.choices.count > 0)
    }

    // MARK: - Streaming Completion

    @Test(.enabled(if: LiveConfig.isEnabled))
    func streamingCompletion() async throws {
        let client = try LLMClient(baseURL: LiveConfig.endpointURL, apiKey: LiveConfig.apiKey)

        let request = try ChatRequest(
            model: LiveConfig.model,
            stream: true,
            messages: [
                TextMessage(role: .user, content: "Count from 1 to 5."),
            ]
        )

        let stream = client.stream(request)
        var accumulated = ""
        var deltaCount = 0

        for try await delta in stream {
            if let content = delta.firstContent {
                accumulated += content
            }
            deltaCount += 1
        }

        #expect(deltaCount > 0, "Expected at least one streaming delta")
        #expect(!accumulated.isEmpty, "Expected accumulated content from stream")
    }

    // MARK: - Tool Calling via ToolSession

    @Test(.enabled(if: LiveConfig.isEnabled))
    func toolCallingWithToolSession() async throws {
        let client = try LLMClient(baseURL: LiveConfig.endpointURL, apiKey: LiveConfig.apiKey)

        let tool = Tool(
            name: "get_current_time",
            description: "Returns the current time",
            parameters: .object(
                properties: [
                    "timezone": .string(description: "Timezone name"),
                ],
                required: ["timezone"]
            )
        )

        let session = ToolSession(
            client: client,
            tools: [tool],
            handlers: ["get_current_time": { _ in
                return "{\"time\": \"2026-03-18T12:00:00Z\"}"
            }]
        )

        let result = try await session.run(
            model: LiveConfig.model,
            messages: [
                TextMessage(role: .user, content: "What time is it in UTC? Use the get_current_time tool."),
            ]
        )

        let content = result.response.firstContent ?? ""
        #expect(!content.isEmpty, "Expected final response after tool calling")
        #expect(result.messages.count > 1, "Expected conversation to have multiple messages from tool loop")
    }

    // MARK: - Agent Multi-Turn

    @Test(.enabled(if: LiveConfig.isEnabled))
    func agentMultiTurn() async throws {
        let client = try LLMClient(baseURL: LiveConfig.endpointURL, apiKey: LiveConfig.apiKey)

        let agent = try Agent(client: client, model: LiveConfig.model) {
            System("You are a helpful assistant. Keep answers very short.")
        }

        let content1 = try await agent.send("My name is Alice.")
        #expect(!content1.isEmpty, "Expected non-empty first response")

        let content2 = try await agent.send("What is my name?")
        #expect(!content2.isEmpty, "Expected non-empty second response")

        let history = await agent.history
        #expect(history.count >= 4, "Expected at least 4 messages in conversation history (system + user + assistant + user + assistant)")
    }
}

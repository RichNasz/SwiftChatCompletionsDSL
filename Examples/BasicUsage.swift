//
//  BasicUsage.swift
//  SwiftChatCompletionsDSL
//
//  Created by Richard Naszcyniec on 6/23/25.
//  Code assisted by AI
//

import Foundation
import SwiftChatCompletionsDSL

/// Basic example demonstrating non-streaming chat completion
@available(macOS 12.0, iOS 15.0, *)
func basicNonStreamingExample() async throws {
	// Initialize the LLM client with your preferred endpoint
	let client = try LLMClient(
		baseURL: "https://api.openai.com/v1/chat/completions",
		apiKey: "your-api-key-here"
	)
	
	// Create a chat request using the declarative DSL syntax
	let request = try ChatRequest(model: "gpt-4o") {
		// Configure optional parameters
		try Temperature(0.7)
		try MaxTokens(150)
		try TopP(0.9)
	} messages: {
		// Build the conversation using result builders
		TextMessage(role: .system, content: "You are a helpful programming assistant.")
		TextMessage(role: .user, content: "Explain the concept of async/await in Swift.")
	}
	
	// Send the request and get the complete response
	do {
		let response = try await client.complete(request)
		
		// Process the response
		if let choice = response.choices.first {
			print("Assistant: \(choice.message.content)")
			print("Finish reason: \(choice.finishReason ?? "none")")
		}
		
		// Show token usage if available
		if let usage = response.usage {
			print("Tokens used: \(usage.totalTokens) (prompt: \(usage.promptTokens), completion: \(usage.completionTokens))")
		}
		
	} catch let error as LLMError {
		print("LLM Error: \(error)")
	} catch {
		print("Unexpected error: \(error)")
	}
}

/// Example demonstrating streaming chat completion for real-time responses
@available(macOS 12.0, iOS 15.0, *)
func basicStreamingExample() async throws {
	// Initialize the LLM client
	let client = try LLMClient(
		baseURL: "https://api.openai.com/v1/chat/completions",
		apiKey: "your-api-key-here"
	)
	
	// Create a streaming request (note stream: true)
	let request = try ChatRequest(model: "gpt-4o", stream: true) {
		try Temperature(0.8)
		try MaxTokens(200)
		try User("example-user")
	} messages: {
		TextMessage(role: .system, content: "You are a creative writing assistant.")
		TextMessage(role: .user, content: "Write a short story about a robot learning to paint.")
	}
	
	// Stream the response and process each chunk
	print("Assistant: ", terminator: "")
	let stream = client.stream(request)
	
	for await delta in stream {
		if let choice = delta.choices.first {
			if let content = choice.delta.content {
				print(content, terminator: "")
				fflush(stdout) // Ensure immediate output
			}
			
			// Check if streaming is complete
			if choice.finishReason != nil {
				print("\n[Stream finished: \(choice.finishReason ?? "unknown")]")
				break
			}
		}
	}
	print() // New line after completion
}

/// Example using custom configuration and error handling
@available(macOS 12.0, iOS 15.0, *)
func advancedConfigurationExample() async throws {
	// Custom URLSession configuration for timeouts
	let sessionConfig = URLSessionConfiguration.default
	sessionConfig.timeoutIntervalForRequest = 30.0
	sessionConfig.timeoutIntervalForResource = 60.0
	
	let client = try LLMClient(
		baseURL: "https://api.openai.com/v1/chat/completions",
		apiKey: "your-api-key-here",
		sessionConfiguration: sessionConfig
	)
	
	// Advanced configuration with multiple parameters
	let request = try ChatRequest(model: "gpt-4o") {
		try Temperature(0.3)
		try MaxTokens(500)
		try TopP(0.95)
		try FrequencyPenalty(0.1)
		try PresencePenalty(-0.1)
		try N(1)
		LogitBias(["AI": 2, "robot": -1]) // Boost "AI", reduce "robot"
		try Stop(["\n\n", "THE END"])
		try User("advanced-user")
	} messages: {
		TextMessage(role: .system, content: "You are a technical documentation writer.")
		TextMessage(role: .user, content: "Explain dependency injection in iOS development.")
	}
	
	do {
		let response = try await client.complete(request)
		
		// Process multiple choices if N > 1
		for (index, choice) in response.choices.enumerated() {
			print("Choice \(index + 1): \(choice.message.content)")
			print("---")
		}
		
	} catch LLMError.rateLimit {
		print("Rate limit exceeded. Please try again later.")
	} catch LLMError.serverError(let statusCode, let message) {
		print("Server error \(statusCode): \(message ?? "Unknown error")")
	} catch LLMError.networkError(let description) {
		print("Network error: \(description)")
	} catch {
		print("Error: \(error)")
	}
}

/// Example using array-based message initialization for conversation history
@available(macOS 12.0, iOS 15.0, *)
func conversationHistoryExample() async throws {
	let client = try LLMClient(
		baseURL: "https://api.openai.com/v1/chat/completions",
		apiKey: "your-api-key-here"
	)
	
	// Pre-built conversation history
	let conversationHistory: [any ChatMessage] = [
		TextMessage(role: .system, content: "You are a helpful coding tutor."),
		TextMessage(role: .user, content: "What is a closure in Swift?"),
		TextMessage(role: .assistant, content: "A closure in Swift is a self-contained block of functionality that can be passed around and used in your code. Closures can capture and store references to any constants and variables from the context in which they are defined."),
		TextMessage(role: .user, content: "Can you give me a simple example?")
	]
	
	// Create request with existing history
	let request = try ChatRequest(model: "gpt-4o") {
		try Temperature(0.5)
		try MaxTokens(300)
	} messages: conversationHistory
	
	let response = try await client.complete(request)
	
	if let content = response.choices.first?.message.content {
		print("Assistant: \(content)")
	}
}

/// Example using ChatConversation for managing ongoing conversations
@available(macOS 12.0, iOS 15.0, *)
func managedConversationExample() async throws {
	let client = try LLMClient(
		baseURL: "https://api.openai.com/v1/chat/completions",
		apiKey: "your-api-key-here"
	)
	
	// Initialize conversation with system message
	var conversation = ChatConversation {
		TextMessage(role: .system, content: "You are a helpful assistant that answers questions concisely.")
	}
	
	// Simulate a multi-turn conversation
	let userQuestions = [
		"What is the capital of France?",
		"What is its population?",
		"What is a famous landmark there?"
	]
	
	for question in userQuestions {
		// Add user message to conversation
		conversation.addUser(content: question)
		
		// Generate request from conversation history
		let request = try conversation.request(model: "gpt-4o") {
			try Temperature(0.7)
			try MaxTokens(100)
		}
		
		// Get response
		let response = try await client.complete(request)
		
		if let assistantResponse = response.choices.first?.message.content {
			print("User: \(question)")
			print("Assistant: \(assistantResponse)")
			print("---")
			
			// Add assistant response to conversation history
			conversation.addAssistant(content: assistantResponse)
		}
		
		// Small delay between requests
		try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
	}
	
	print("Final conversation has \(conversation.history.count) messages")
}

/// Example demonstrating tool/function calling (if supported by the model)
@available(macOS 12.0, iOS 15.0, *)
func functionCallingExample() async throws {
	let client = try LLMClient(
		baseURL: "https://api.openai.com/v1/chat/completions",
		apiKey: "your-api-key-here"
	)
	
	// Define available tools/functions
	let weatherTool = Tool(function: Tool.Function(
		name: "get_weather",
		description: "Get the current weather for a location",
		parameters: [
			"location": "string",
			"unit": "string"
		]
	))
	
	let calculatorTool = Tool(function: Tool.Function(
		name: "calculate",
		description: "Perform basic mathematical calculations",
		parameters: [
			"expression": "string"
		]
	))
	
	let request = try ChatRequest(model: "gpt-4o") {
		try Temperature(0.1)
		try MaxTokens(200)
		Tools([weatherTool, calculatorTool])
	} messages: {
		TextMessage(role: .user, content: "What's the weather like in San Francisco and what's 15 * 23?")
	}
	
	let response = try await client.complete(request)
	
	if let choice = response.choices.first {
		print("Assistant response: \(choice.message.content)")
		print("Finish reason: \(choice.finishReason ?? "none")")
	}
}

// MARK: - Main execution examples

@available(macOS 12.0, iOS 15.0, *)
@main
struct ExampleRunner {
	static func main() async {
		print("SwiftChatCompletionsDSL Examples")
		print("=================================")
		
		// Note: Replace "your-api-key-here" with your actual API key before running
		
		do {
			print("\n1. Basic Non-Streaming Example:")
			try await basicNonStreamingExample()
			
			print("\n2. Basic Streaming Example:")
			try await basicStreamingExample()
			
			print("\n3. Advanced Configuration Example:")
			try await advancedConfigurationExample()
			
			print("\n4. Conversation History Example:")
			try await conversationHistoryExample()
			
			print("\n5. Managed Conversation Example:")
			try await managedConversationExample()
			
			print("\n6. Function Calling Example:")
			try await functionCallingExample()
			
		} catch {
			print("Example failed with error: \(error)")
		}
	}
}

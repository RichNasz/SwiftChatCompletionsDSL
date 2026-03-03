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
@available(macOS 13.0, iOS 16.0, *)
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
		// Use System() and UserMessage() convenience functions or TextMessage()
		System("You are a helpful programming assistant.")
		UserMessage("Explain the concept of async/await in Swift.")
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
@available(macOS 13.0, iOS 16.0, *)
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
		try UserID("example-user")
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
@available(macOS 13.0, iOS 16.0, *)
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
		try UserID("advanced-user")
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
@available(macOS 13.0, iOS 16.0, *)
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
@available(macOS 13.0, iOS 16.0, *)
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

/// Example demonstrating tool/function calling with JSONSchema
func functionCallingExample() async throws {
	let client = try LLMClient(
		baseURL: "https://api.openai.com/v1/chat/completions",
		apiKey: "your-api-key-here"
	)

	// Define tools with type-safe JSONSchema parameters
	let weatherTool = Tool(function: Tool.Function(
		name: "get_weather",
		description: "Get the current weather for a location",
		parameters: .object(
			properties: [
				"location": .string(description: "The city and state, e.g. San Francisco, CA"),
				"unit": .string(description: "Temperature unit", enumValues: ["celsius", "fahrenheit"]),
			],
			required: ["location"]
		)
	))

	let calculatorTool = Tool(function: Tool.Function(
		name: "calculate",
		description: "Perform basic mathematical calculations",
		parameters: .object(
			properties: [
				"expression": .string(description: "The math expression to evaluate"),
			],
			required: ["expression"]
		)
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

/// Example demonstrating ToolSession for automatic tool-calling loops
func toolSessionExample() async throws {
	let client = try LLMClient(
		baseURL: "https://api.openai.com/v1/chat/completions",
		apiKey: "your-api-key-here"
	)

	let weatherTool = Tool(function: Tool.Function(
		name: "get_weather",
		description: "Get weather for a location",
		parameters: .object(
			properties: [
				"location": .string(description: "City name"),
			],
			required: ["location"]
		)
	))

	// ToolSession handles the send → tool_calls → execute → results → repeat loop
	let session = ToolSession(
		client: client,
		tools: [weatherTool],
		handlers: ["get_weather": { arguments in
			// Parse arguments JSON and return result
			return "{\"temperature\": 72, \"condition\": \"sunny\"}"
		}]
	)

	let result = try await session.run(
		model: "gpt-4o",
		messages: [TextMessage(role: .user, content: "What's the weather in Paris?")]
	)

	print("Final response: \(result.response.firstContent ?? "")")
	print("Tool calls made: \(result.log.count)")
	print("Iterations: \(result.iterations)")
}

/// Example demonstrating the Agent actor for persistent conversations with tools
func agentExample() async throws {
	let client = try LLMClient(
		baseURL: "https://api.openai.com/v1/chat/completions",
		apiKey: "your-api-key-here"
	)

	// Create an Agent with tools using the builder pattern
	let agent = try Agent(
		client: client,
		model: "gpt-4o",
		systemPrompt: "You are a helpful assistant with access to weather data."
	) {
		try Temperature(0.7)
	} tools: {
		AgentTool(
			tool: Tool(function: Tool.Function(
				name: "get_weather",
				description: "Get weather for a location",
				parameters: .object(
					properties: ["location": .string(description: "City name")],
					required: ["location"]
				)
			))
		) { arguments in
			return "{\"temperature\": 72, \"condition\": \"sunny\"}"
		}
	}

	// Multi-turn conversation - agent maintains history automatically
	let response1 = try await agent.send("What's the weather in Paris?")
	print("Agent: \(response1)")

	let response2 = try await agent.send("How about London?")
	print("Agent: \(response2)")

	// Check transcript for debugging
	let transcript = await agent.transcript
	for entry in transcript {
		switch entry {
		case .userMessage(let msg): print("  [User] \(msg)")
		case .assistantMessage(let msg): print("  [Assistant] \(msg)")
		case .toolCall(let name, _): print("  [Tool Call] \(name)")
		case .toolResult(let name, _, let duration): print("  [Tool Result] \(name) (\(duration))")
		case .error(let msg): print("  [Error] \(msg)")
		}
	}
}

/// Example demonstrating an Agent with multiple tools working together
///
/// This agent has access to weather, calendar, and restaurant tools,
/// allowing it to handle complex queries that require combining information
/// from multiple sources in a single conversation.
func multiToolAgentExample() async throws {
	let client = try LLMClient(
		baseURL: "https://api.openai.com/v1/chat/completions",
		apiKey: "your-api-key-here"
	)

	let agent = try Agent(
		client: client,
		model: "gpt-4o",
		systemPrompt: """
			You are a personal assistant that can check weather, look up calendar events,
			and find restaurants. Combine information from multiple tools when helpful.
			""",
		maxToolIterations: 5
	) {
		try Temperature(0.7)
		try MaxTokens(500)
	} tools: {
		// Tool 1: Weather lookup
		AgentTool(
			tool: Tool(function: Tool.Function(
				name: "get_weather",
				description: "Get current weather for a city",
				parameters: .object(
					properties: [
						"city": .string(description: "City name"),
						"unit": .string(
							description: "Temperature unit",
							enumValues: ["celsius", "fahrenheit"]
						),
					],
					required: ["city"]
				)
			))
		) { arguments in
			let args = try JSONDecoder().decode(
				[String: String].self,
				from: arguments.data(using: .utf8)!
			)
			let city = args["city"] ?? "unknown"
			// Simulate weather API response
			return """
				{"city": "\(city)", "temperature": 22, "unit": "celsius", "condition": "partly cloudy", "humidity": 65}
				"""
		}

		// Tool 2: Calendar lookup
		AgentTool(
			tool: Tool(function: Tool.Function(
				name: "get_calendar_events",
				description: "Get calendar events for a specific date",
				parameters: .object(
					properties: [
						"date": .string(description: "Date in YYYY-MM-DD format"),
					],
					required: ["date"]
				)
			))
		) { arguments in
			// Simulate calendar API response
			return """
				{"events": [
					{"time": "10:00", "title": "Team standup", "duration": "30min"},
					{"time": "12:00", "title": "Lunch free", "duration": "60min"},
					{"time": "14:00", "title": "Design review", "duration": "45min"}
				]}
				"""
		}

		// Tool 3: Restaurant search
		AgentTool(
			tool: Tool(function: Tool.Function(
				name: "search_restaurants",
				description: "Search for restaurants near a location",
				parameters: .object(
					properties: [
						"location": .string(description: "City or address"),
						"cuisine": .string(description: "Type of cuisine (optional)"),
						"outdoor_seating": .boolean(description: "Whether outdoor seating is required"),
					],
					required: ["location"]
				)
			))
		) { arguments in
			// Simulate restaurant search response
			return """
				{"restaurants": [
					{"name": "Le Petit Bistro", "cuisine": "French", "rating": 4.5, "outdoor_seating": true},
					{"name": "Sakura Garden", "cuisine": "Japanese", "rating": 4.7, "outdoor_seating": false},
					{"name": "Trattoria Roma", "cuisine": "Italian", "rating": 4.3, "outdoor_seating": true}
				]}
				"""
		}
	}

	// The model can call multiple tools to answer complex queries
	print("--- Multi-tool query ---")
	let response1 = try await agent.send(
		"I'm in Paris today. What's the weather like, what's on my calendar, and can you suggest a restaurant with outdoor seating for my lunch break?"
	)
	print("Agent: \(response1)")

	// Follow-up uses conversation history — no need to repeat context
	print("\n--- Follow-up ---")
	let response2 = try await agent.send(
		"Actually, what about Japanese food instead?"
	)
	print("Agent: \(response2)")

	// Inspect which tools were called
	print("\n--- Tool activity log ---")
	print("Registered tools: \(await agent.registeredToolNames)")
	let transcript = await agent.transcript
	for entry in transcript {
		switch entry {
		case .toolCall(let name, let args):
			print("  Called \(name) with \(args)")
		case .toolResult(let name, _, let duration):
			print("  \(name) returned in \(duration)")
		default:
			break
		}
	}
}

/// Example demonstrating multi-agent orchestration
///
/// This pattern uses specialized agents for different domains and a coordinator
/// that routes user requests to the appropriate agent. Each agent maintains
/// its own conversation history and tools.
func multiAgentOrchestrationExample() async throws {
	let client = try LLMClient(
		baseURL: "https://api.openai.com/v1/chat/completions",
		apiKey: "your-api-key-here"
	)

	// --- Agent 1: Research Agent ---
	// Specializes in looking up information
	let researchAgent = try Agent(
		client: client,
		model: "gpt-4o",
		systemPrompt: """
			You are a research assistant. Use your tools to look up facts and provide
			accurate, well-sourced answers. Always cite which tool you used.
			"""
	) {
		try Temperature(0.3) // Low temperature for factual accuracy
		try MaxTokens(300)
	} tools: {
		AgentTool(
			tool: Tool(function: Tool.Function(
				name: "search_knowledge_base",
				description: "Search an internal knowledge base for information",
				parameters: .object(
					properties: [
						"query": .string(description: "Search query"),
						"category": .string(
							description: "Category to search in",
							enumValues: ["science", "history", "technology", "business"]
						),
					],
					required: ["query"]
				)
			))
		) { arguments in
			return """
				{"results": [
					{"title": "Swift Concurrency", "snippet": "Swift concurrency model uses async/await, actors, and structured concurrency for safe parallel code."},
					{"title": "Actor Model", "snippet": "Actors provide data isolation by ensuring only one task accesses their mutable state at a time."}
				]}
				"""
		}
	}

	// --- Agent 2: Code Agent ---
	// Specializes in writing and analyzing code
	let codeAgent = try Agent(
		client: client,
		model: "gpt-4o",
		systemPrompt: """
			You are a code assistant. You can run code snippets and analyze their output.
			Provide clear, well-commented code examples.
			"""
	) {
		try Temperature(0.2) // Very low for precise code
		try MaxTokens(500)
	} tools: {
		AgentTool(
			tool: Tool(function: Tool.Function(
				name: "run_code",
				description: "Execute a Swift code snippet and return the output",
				parameters: .object(
					properties: [
						"code": .string(description: "Swift code to execute"),
					],
					required: ["code"]
				)
			))
		) { arguments in
			// Simulate code execution
			return """
				{"output": "Hello, World!\\nExecution time: 0.002s", "exit_code": 0}
				"""
		}

		AgentTool(
			tool: Tool(function: Tool.Function(
				name: "analyze_complexity",
				description: "Analyze the time and space complexity of a code snippet",
				parameters: .object(
					properties: [
						"code": .string(description: "Code to analyze"),
					],
					required: ["code"]
				)
			))
		) { arguments in
			return """
				{"time_complexity": "O(n log n)", "space_complexity": "O(n)", "notes": "Dominated by the sorting step"}
				"""
		}
	}

	// --- Agent 3: Summary Agent ---
	// Specializes in synthesizing information (no tools needed)
	let summaryAgent = Agent(
		client: client,
		model: "gpt-4o",
		systemPrompt: """
			You are a summarization expert. You receive information gathered by other
			assistants and synthesize it into a clear, concise summary for the user.
			Structure your response with bullet points and a brief conclusion.
			"""
	)

	// --- Orchestration Logic ---
	// A simple router that sends queries to the right agent based on intent

	/// Routes a user query to the appropriate specialized agent.
	func route(_ query: String) async throws -> (agent: String, response: String) {
		// Simple keyword-based routing (in production, use an LLM classifier)
		let lowered = query.lowercased()
		if lowered.contains("code") || lowered.contains("function") || lowered.contains("implement") {
			let response = try await codeAgent.send(query)
			return ("Code Agent", response)
		} else if lowered.contains("research") || lowered.contains("explain") || lowered.contains("what is") {
			let response = try await researchAgent.send(query)
			return ("Research Agent", response)
		} else {
			let response = try await summaryAgent.send(query)
			return ("Summary Agent", response)
		}
	}

	// --- Run the orchestration ---

	let queries = [
		"What is the actor model in Swift concurrency?",
		"Implement a simple async queue in Swift",
		"Summarize the key benefits of structured concurrency",
	]

	var allResponses: [String] = []

	for query in queries {
		print("User: \(query)")
		let (agentName, response) = try await route(query)
		print("[\(agentName)] \(response)\n")
		allResponses.append("[\(agentName)]: \(response)")
	}

	// Feed all responses to the summary agent for a final synthesis
	print("--- Final Synthesis ---")
	let synthesisPrompt = """
		Here are findings from multiple research and coding assistants:

		\(allResponses.joined(separator: "\n\n"))

		Please provide a unified summary of everything learned.
		"""
	let synthesis = try await summaryAgent.send(synthesisPrompt)
	print("Summary Agent: \(synthesis)")

	// Each agent's history is independent
	print("\n--- Agent Statistics ---")
	print("Research Agent: \(await researchAgent.history.count) messages, \(await researchAgent.toolCount) tools")
	print("Code Agent: \(await codeAgent.history.count) messages, \(await codeAgent.toolCount) tools")
	print("Summary Agent: \(await summaryAgent.history.count) messages, \(await summaryAgent.toolCount) tools")
}

/// Example demonstrating timeout configuration for different use cases
@available(macOS 13.0, iOS 16.0, *)
func timeoutConfigurationExample() async throws {
	let client = try LLMClient(
		baseURL: "https://api.openai.com/v1/chat/completions",
		apiKey: "your-api-key-here"
	)

	// Example 1: Quick request with short timeout
	print("=== Quick Request Example ===")
	let quickRequest = try ChatRequest(model: "gpt-4o") {
		try Temperature(0.3)
		try MaxTokens(50)
		try RequestTimeout(30)    // 30 seconds for quick response
		try ResourceTimeout(60)   // 1 minute total
	} messages: {
		TextMessage(role: .user, content: "What is 2+2?")
	}

	do {
		let response = try await client.complete(quickRequest)
		if let content = response.choices.first?.message.content {
			print("Quick response: \(content)")
		}
	} catch LLMError.networkError(let description) {
		print("Network/timeout error: \(description)")
	}

	// Example 2: Standard conversation with moderate timeout
	print("\n=== Standard Conversation Example ===")
	let standardRequest = try ChatRequest(model: "gpt-4o") {
		try Temperature(0.7)
		try MaxTokens(200)
		try RequestTimeout(120)   // 2 minutes for standard processing
		try ResourceTimeout(300)  // 5 minutes total
	} messages: {
		TextMessage(role: .system, content: "You are a helpful programming assistant.")
		TextMessage(role: .user, content: "Explain the difference between structs and classes in Swift.")
	}

	do {
		let response = try await client.complete(standardRequest)
		if let content = response.choices.first?.message.content {
			print("Standard response: \(content)")
		}
	} catch LLMError.networkError(let description) {
		print("Network/timeout error: \(description)")
	}

	// Example 3: Long document generation with extended timeout
	print("\n=== Long Document Generation Example ===")
	let longRequest = try ChatRequest(model: "gpt-4o") {
		try Temperature(0.8)
		try MaxTokens(1000)
		try RequestTimeout(600)    // 10 minutes for complex generation
		try ResourceTimeout(1200)  // 20 minutes total
	} messages: {
		TextMessage(role: .system, content: "You are a technical documentation writer.")
		TextMessage(role: .user, content: "Write a comprehensive guide on Swift concurrency, including async/await, actors, and task groups.")
	}

	do {
		let response = try await client.complete(longRequest)
		if let content = response.choices.first?.message.content {
			print("Long document response: \(content.prefix(200))...")
		}
	} catch LLMError.networkError(let description) {
		print("Network/timeout error for long request: \(description)")
	}

	// Example 4: Streaming with timeout configuration
	print("\n=== Streaming with Timeout Example ===")
	let streamingRequest = try ChatRequest(model: "gpt-4o", stream: true) {
		try Temperature(0.7)
		try MaxTokens(300)
		try RequestTimeout(180)   // 3 minutes for streaming
		try ResourceTimeout(450)  // 7.5 minutes total
	} messages: {
		TextMessage(role: .user, content: "Write a short story about a robot learning to code.")
	}

	print("Streaming response: ", terminator: "")
	let stream = client.stream(streamingRequest)

	for await delta in stream {
		if let content = delta.choices.first?.delta.content {
			print(content, terminator: "")
		}
		if delta.choices.first?.finishReason != nil {
			break
		}
	}
	print("\nStreaming completed.")

	// Example 5: Error handling for timeout scenarios
	print("\n=== Timeout Error Handling Example ===")
	let timeoutRequest = try ChatRequest(model: "gpt-4o") {
		try Temperature(0.7)
		try RequestTimeout(10)    // Very short timeout to demonstrate error handling
		try ResourceTimeout(30)
	} messages: {
		TextMessage(role: .user, content: "Write a very long detailed analysis that will likely exceed the timeout.")
	}

	do {
		let response = try await client.complete(timeoutRequest)
		print("Unexpected success: \(response.choices.first?.message.content ?? "No content")")
	} catch LLMError.networkError(let description) {
		print("Expected timeout error: \(description)")
	} catch {
		print("Other error: \(error)")
	}
}

// MARK: - Main execution examples

@available(macOS 13.0, iOS 16.0, *)
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

			print("\n7. Timeout Configuration Example:")
			try await timeoutConfigurationExample()

			print("\n8. Tool Session Example:")
			try await toolSessionExample()

			print("\n9. Agent Example:")
			try await agentExample()

			print("\n10. Multi-Tool Agent Example:")
			try await multiToolAgentExample()

			print("\n11. Multi-Agent Orchestration Example:")
			try await multiAgentOrchestrationExample()

		} catch {
			print("Example failed with error: \(error)")
		}
	}
}
